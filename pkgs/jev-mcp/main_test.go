package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

// No live network in tests.
type rtFunc func(*http.Request) (*http.Response, error)

func (f rtFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func fakeResp(status int, body string) *http.Response {
	return &http.Response{
		StatusCode: status,
		Header:     http.Header{},
		Body:       io.NopCloser(strings.NewReader(body)),
	}
}

func testConfig(t *testing.T, transport http.RoundTripper) config {
	t.Helper()
	return config{
		baseURL: "https://example.invalid/v1",
		model:   "orvix/jev",
		token:   "test-token",
		client:  &http.Client{Transport: transport},
	}
}

func init() { retryDelay = 0 } // keep the single retry instant in tests

// ── question array → upstream object ─────────────────────────────────────

func TestQuestionMap(t *testing.T) {
	got := questionMap([]question{
		{ID: "a", Instructions: "is it code?"},
		{ID: "b", Instructions: "pick one", Type: "choice",
			Criteria: map[string]string{"bugfix": "fix", "feature": "new"}},
	})
	if len(got) != 2 {
		t.Fatalf("want 2 entries, got %d", len(got))
	}
	// type defaults to noul when omitted
	if got["a"].Type != "noul" {
		t.Errorf("a.Type = %q, want noul", got["a"].Type)
	}
	if got["a"].Instructions != "is it code?" {
		t.Errorf("a.Instructions = %q", got["a"].Instructions)
	}
	if got["b"].Type != "choice" || got["b"].Criteria["feature"] != "new" {
		t.Errorf("b = %+v, want choice with criteria passthrough", got["b"])
	}
}

// ── fresh: verified upstream body, answers untouched ─────────────────────

func TestEvaluateFresh(t *testing.T) {
	body := `{"model":"orvix/jev",` +
		`"answers":{"needs_code":{"noul":0.96,"type":"noul"},` +
		`"kind":{"choice":"feature","confidence":1.0,` +
		`"probabilities":{"bugfix":0.0,"feature":1.0},"type":"choice"}},` +
		`"usage":{"input_tokens":346,"output_tokens":50}}`
	cfg := testConfig(t, rtFunc(func(r *http.Request) (*http.Response, error) {
		if got := r.Header.Get("Authorization"); got != "Bearer test-token" {
			t.Errorf("Authorization = %q", got)
		}
		if !strings.HasSuffix(r.URL.Path, "/evaluate") {
			t.Errorf("path = %q", r.URL.Path)
		}
		return fakeResp(200, body), nil
	}))

	env := cfg.evaluate(t.Context(), "some text", []question{{ID: "needs_code", Instructions: "code?"}})
	if env.State != "fresh" {
		t.Fatalf("state = %q (%v)", env.State, env.Diagnostics)
	}
	if env.Contract != contract || env.Model != "orvix/jev" {
		t.Errorf("contract/model = %q/%q", env.Contract, env.Model)
	}
	if env.Verified {
		t.Error("verified must always be false — jev output is not evidence")
	}
	if len(env.Answers) != 2 {
		t.Fatalf("answers = %v", env.Answers)
	}
	// confidence/probabilities passed through byte-for-byte, not clamped
	if k := string(env.Answers["kind"]); !strings.Contains(k, `"confidence":1.0`) ||
		!strings.Contains(k, `"probabilities"`) {
		t.Errorf("choice answer was mutated: %s", k)
	}
	if k := string(env.Answers["needs_code"]); !strings.Contains(k, `"noul":0.96`) {
		t.Errorf("noul answer was mutated: %s", k)
	}

	// envelope marshals with verified:false present (no omitempty)
	b, _ := json.Marshal(env)
	if !strings.Contains(string(b), `"verified":false`) {
		t.Errorf("envelope missing verified:false: %s", b)
	}
}

// ── config_error: no token, no network ───────────────────────────────────

func TestEvaluateConfigError(t *testing.T) {
	cfg := testConfig(t, rtFunc(func(*http.Request) (*http.Response, error) {
		t.Fatal("no network call may happen without a token")
		return nil, nil
	}))
	cfg.token = ""
	env := cfg.evaluate(t.Context(), "x", []question{{ID: "a", Instructions: "b"}})
	if env.State != "config_error" {
		t.Fatalf("state = %q, want config_error", env.State)
	}
	if len(env.Diagnostics) != 1 || !strings.Contains(env.Diagnostics[0], "ORVIX_TOKEN") {
		t.Errorf("diagnostics = %v", env.Diagnostics)
	}
}

// ── upstream_error: 404 (e.g. a non-evaluator JEV_MODEL) surfaces the message

func TestEvaluateUpstreamError(t *testing.T) {
	cfg := testConfig(t, rtFunc(func(*http.Request) (*http.Response, error) {
		return fakeResp(404, `{"error":{"message":"model 'auto' is not an Orvix evaluator. Use POST /v1/evaluate with orvix/jev.","type":"invalid_request_error"}}`), nil
	}))
	env := cfg.evaluate(t.Context(), "x", []question{{ID: "a", Instructions: "b"}})
	if env.State != "upstream_error" {
		t.Fatalf("state = %q, want upstream_error", env.State)
	}
	if len(env.Diagnostics) == 0 || env.Diagnostics[0] != "http_404" {
		t.Errorf("diagnostics = %v", env.Diagnostics)
	}
	if !strings.Contains(env.Error, "not an Orvix evaluator") {
		t.Errorf("error = %q", env.Error)
	}
}

// ── one retry max on 5xx ─────────────────────────────────────────────────

func TestEvaluateRetries5xxOnce(t *testing.T) {
	calls := 0
	cfg := testConfig(t, rtFunc(func(*http.Request) (*http.Response, error) {
		calls++
		if calls == 1 {
			return fakeResp(502, "bad gateway"), nil
		}
		return fakeResp(200, `{"model":"orvix/jev","answers":{"a":{"noul":0.9,"type":"noul"}},"usage":{}}`), nil
	}))
	env := cfg.evaluate(t.Context(), "x", []question{{ID: "a", Instructions: "b"}})
	if calls != 2 {
		t.Errorf("calls = %d, want 2", calls)
	}
	if env.State != "fresh" {
		t.Fatalf("state = %q (%v)", env.State, env.Diagnostics)
	}
}

func TestEvaluateGivesUpAfterOneRetry(t *testing.T) {
	calls := 0
	cfg := testConfig(t, rtFunc(func(*http.Request) (*http.Response, error) {
		calls++
		return fakeResp(503, "down"), nil
	}))
	env := cfg.evaluate(t.Context(), "x", []question{{ID: "a", Instructions: "b"}})
	if calls != 2 {
		t.Errorf("calls = %d, want 2 (one retry max)", calls)
	}
	if env.State != "upstream_error" || env.Diagnostics[0] != "http_503" {
		t.Errorf("env = %+v", env)
	}
}

// ── framing / dispatch ───────────────────────────────────────────────────

func TestServeFraming(t *testing.T) {
	cfg := testConfig(t, rtFunc(func(*http.Request) (*http.Response, error) {
		t.Fatal("tools/list must not touch the network")
		return nil, nil
	}))
	in := strings.Join([]string{
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}`,
		`{"jsonrpc":"2.0","method":"notifications/initialized"}`, // no reply
		`{"jsonrpc":"2.0","id":2,"method":"tools/list"}`,
		`{"jsonrpc":"2.0","id":3,"method":"does/not/exist"}`,
		"",
	}, "\n")
	var out bytes.Buffer
	if err := serve(cfg, strings.NewReader(in), &out); err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	if len(lines) != 3 {
		t.Fatalf("want 3 replies (notification skipped), got %d: %s", len(lines), out.String())
	}

	var init struct {
		Result struct {
			ProtocolVersion string `json:"protocolVersion"`
			ServerInfo      struct {
				Name string `json:"name"`
			} `json:"serverInfo"`
		} `json:"result"`
	}
	if err := json.Unmarshal([]byte(lines[0]), &init); err != nil {
		t.Fatal(err)
	}
	if init.Result.ServerInfo.Name != "jev" || init.Result.ProtocolVersion != protocolVersion {
		t.Errorf("initialize = %+v", init.Result)
	}

	var list struct {
		Result struct {
			Tools []tool `json:"tools"`
		} `json:"result"`
	}
	if err := json.Unmarshal([]byte(lines[1]), &list); err != nil {
		t.Fatal(err)
	}
	if len(list.Result.Tools) != 1 || list.Result.Tools[0].Name != toolName {
		t.Fatalf("tools/list = %+v, want exactly jev_evaluate", list.Result.Tools)
	}
	for _, m := range []string{"state", "questions"} {
		if _, ok := list.Result.Tools[0].InputSchema["properties"].(map[string]any)[m]; !ok {
			t.Errorf("inputSchema missing %q", m)
		}
	}

	var bad struct {
		Error *rpcError `json:"error"`
	}
	if err := json.Unmarshal([]byte(lines[2]), &bad); err != nil {
		t.Fatal(err)
	}
	if bad.Error == nil || bad.Error.Code != -32601 {
		t.Errorf("unknown method = %+v, want -32601", bad.Error)
	}
}

func TestServeParseErrorDoesNotKillSession(t *testing.T) {
	cfg := testConfig(t, nil)
	in := "{not json}\n{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/list\"}\n"
	var out bytes.Buffer
	if err := serve(cfg, strings.NewReader(in), &out); err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	if len(lines) != 2 || !strings.Contains(lines[0], "-32700") {
		t.Fatalf("out = %q", out.String())
	}
}

// ── tools/call argument validation ───────────────────────────────────────

func TestCallToolValidation(t *testing.T) {
	cfg := testConfig(t, rtFunc(func(*http.Request) (*http.Response, error) {
		t.Fatal("invalid args must not reach the network")
		return nil, nil
	}))
	cases := []struct {
		name string
		args string
	}{
		{"missing state", `{"questions":[{"id":"a","instructions":"b"}]}`},
		{"no questions", `{"state":"x","questions":[]}`},
		{"too many questions", `{"state":"x","questions":[` +
			`{"id":"1","instructions":"i"},{"id":"2","instructions":"i"},{"id":"3","instructions":"i"},` +
			`{"id":"4","instructions":"i"},{"id":"5","instructions":"i"},{"id":"6","instructions":"i"},` +
			`{"id":"7","instructions":"i"},{"id":"8","instructions":"i"},{"id":"9","instructions":"i"}]}`},
		{"empty instructions", `{"state":"x","questions":[{"id":"a","instructions":""}]}`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			params, _ := json.Marshal(callParams{Name: toolName, Arguments: json.RawMessage(tc.args)})
			resp := callTool(cfg, json.RawMessage("1"), params)
			if resp.Error != nil {
				t.Fatalf("unexpected rpc error: %+v", resp.Error)
			}
			m := resp.Result.(map[string]any)
			if m["isError"] != true {
				t.Errorf("want isError=true, got %+v", m)
			}
		})
	}
}

func TestCallToolUnknownTool(t *testing.T) {
	cfg := testConfig(t, nil)
	params, _ := json.Marshal(callParams{Name: "nope", Arguments: json.RawMessage(`{}`)})
	resp := callTool(cfg, json.RawMessage("1"), params)
	if resp.Error == nil || resp.Error.Code != -32602 {
		t.Fatalf("want -32602, got %+v", resp.Error)
	}
}
