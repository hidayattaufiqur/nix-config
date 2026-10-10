// Command jev-mcp is a tiny stdio MCP server exposing exactly one tool,
// jev_evaluate, backed by the Orvix evaluator endpoint (orvix/jev).
//
// jev is an *evaluator*, not a chat model: POST /v1/chat/completions with
// orvix/jev hard-fails with 400 and tells you to use /v1/evaluate. So it can
// never be a Hermes provider entry — it needs a tool.
//
// ponytail: stdlib only, one file, no MCP SDK. A reused http.Client plus
// line-delimited JSON-RPC over bufio keeps an idle process at a few MB RSS
// (the low-memory requirement). Upgrade path: add concurrency or a
// streamable-HTTP transport only if a client actually needs them.
package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	protocolVersion = "2024-11-05"
	contract        = "jev.evaluate.v1"
	serverName      = "jev"
	serverVersion   = "0.1.0"
	toolName        = "jev_evaluate"
	maxQuestions    = 8
	requestTimeout  = 20 * time.Second
)

const toolDescription = "Use when you need a fast classification or confidence score over a piece of " +
	"text (routing, gating, triage) — NOT for generation. jev answers only the questions " +
	"you pose, as labels or 0..1 scores. Output is a routing signal, never evidence for " +
	"metadata claims — jev does not know platform metadata, so never cite it (verified=false). " +
	"Domain-neutral: the caller supplies the questions; D365FO triage is just one caller. " +
	"Prefer one call with several questions over several calls. " +
	"Example (triage a card): state=\"Card: rewrite the tool descriptions to start with Use when. " +
	"Blocked by a root restart.\", questions={blocked:{type:\"noul\",instructions:\"Is this blocked?\"}} " +
	"-> blocked≈0.96. Example (D365FO text): state=\"can you add a CustTable extension that blocks " +
	"posting over the credit limit?\", questions={needs_code:{type:\"boolean\",instructions:" +
	"\"Is the user asking for a code change?\"}} -> needs_code≈0.96."

// retryDelay separates the single retry on a transient (5xx / transport)
// failure. A var so tests can zero it.
var retryDelay = 300 * time.Millisecond

// ── JSON-RPC / MCP wire types ────────────────────────────────────────────

type rpcRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Result  any             `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

type callParams struct {
	Name      string          `json:"name"`
	Arguments json.RawMessage `json:"arguments"`
}

type tool struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	InputSchema map[string]any `json:"inputSchema"`
}

// ── tool input / upstream contract ───────────────────────────────────────

type question struct {
	ID           string            `json:"id"`
	Instructions string            `json:"instructions"`
	Type         string            `json:"type,omitempty"`
	Criteria     map[string]string `json:"criteria,omitempty"`
}

type upstreamQuestion struct {
	Type         string            `json:"type"`
	Instructions string            `json:"instructions"`
	Criteria     map[string]string `json:"criteria,omitempty"`
}

type evalRequest struct {
	Model     string                      `json:"model"`
	State     string                      `json:"state"`
	Questions map[string]upstreamQuestion `json:"questions"`
}

type evalResponse struct {
	Model   string                     `json:"model"`
	Answers map[string]json.RawMessage `json:"answers"`
	Usage   json.RawMessage            `json:"usage"`
}

// envelope is what agents read. Small and stable; verified is always false —
// jev output is a routing signal, never citable evidence.
type envelope struct {
	Contract    string                     `json:"contract"`
	State       string                     `json:"state"` // fresh|config_error|upstream_error
	Model       string                     `json:"model"`
	Verified    bool                       `json:"verified"`
	Answers     map[string]json.RawMessage `json:"answers,omitempty"`
	Usage       json.RawMessage            `json:"usage,omitempty"`
	Error       string                     `json:"error,omitempty"`
	Diagnostics []string                   `json:"diagnostics,omitempty"`
}

type config struct {
	baseURL string
	model   string
	token   string
	client  *http.Client
}

func loadConfig() config {
	return config{
		baseURL: envOr("ORVIX_BASE_URL", "https://api.orvix.id/v1"),
		model:   envOr("JEV_MODEL", "orvix/jev"),
		token:   os.Getenv("ORVIX_TOKEN"),
		client:  &http.Client{Timeout: requestTimeout},
	}
}

func envOr(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

// questionMap maps the tool's question *array* onto the upstream `questions`
// *object* keyed by id (upstream rejects arrays — with a misleading error).
func questionMap(qs []question) map[string]upstreamQuestion {
	out := make(map[string]upstreamQuestion, len(qs))
	for _, q := range qs {
		t := q.Type
		if t == "" {
			t = "noul"
		}
		out[q.ID] = upstreamQuestion{Type: t, Instructions: q.Instructions, Criteria: q.Criteria}
	}
	return out
}

// evaluate performs one upstream call. Never panics, never prints the token.
func (c config) evaluate(ctx context.Context, state string, qs []question) envelope {
	env := envelope{Contract: contract, State: "fresh", Model: c.model}
	if c.token == "" {
		env.State = "config_error"
		env.Diagnostics = []string{"ORVIX_TOKEN is not set"}
		return env
	}
	body, err := json.Marshal(evalRequest{Model: c.model, State: state, Questions: questionMap(qs)})
	if err != nil {
		env.State = "upstream_error"
		env.Diagnostics = []string{"encode request: " + err.Error()}
		return env
	}
	url := strings.TrimRight(c.baseURL, "/") + "/evaluate"

	for attempt := 0; ; attempt++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
		if err != nil {
			env.State = "upstream_error"
			env.Diagnostics = []string{"build request: " + err.Error()}
			return env
		}
		req.Header.Set("Authorization", "Bearer "+c.token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := c.client.Do(req)
		if err != nil {
			if attempt == 0 {
				time.Sleep(retryDelay) // transient transport blip
				continue
			}
			env.State = "upstream_error"
			env.Diagnostics = []string{"transport: " + err.Error()}
			return env
		}
		raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
		resp.Body.Close()

		if resp.StatusCode >= 500 && attempt == 0 { // one retry max on 5xx/502
			time.Sleep(retryDelay)
			continue
		}
		if resp.StatusCode != http.StatusOK {
			env.State = "upstream_error"
			env.Diagnostics = []string{"http_" + strconv.Itoa(resp.StatusCode)}
			env.Error = upstreamMessage(raw)
			return env
		}
		var er evalResponse
		if err := json.Unmarshal(raw, &er); err != nil {
			env.State = "upstream_error"
			env.Diagnostics = []string{"http_200", "decode: " + err.Error()}
			return env
		}
		env.Answers = er.Answers
		env.Usage = er.Usage
		return env
	}
}

// upstreamMessage pulls the human message out of {"error":{"message":...}}.
func upstreamMessage(raw []byte) string {
	var e struct {
		Error struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if json.Unmarshal(raw, &e) == nil && e.Error.Message != "" {
		return e.Error.Message
	}
	s := strings.TrimSpace(string(raw))
	if len(s) > 300 {
		s = s[:300]
	}
	return s
}

// ── MCP surface ──────────────────────────────────────────────────────────

func jevTool() tool {
	return tool{
		Name:        toolName,
		Description: toolDescription,
		InputSchema: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"state": map[string]any{
					"type":        "string",
					"description": "The text to judge.",
				},
				"questions": map[string]any{
					"type":     "array",
					"minItems": 1,
					"maxItems": maxQuestions,
					"items": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"id": map[string]any{
								"type":        "string",
								"description": "Answer key this question is reported under.",
							},
							"instructions": map[string]any{
								"type":        "string",
								"description": "What to decide or measure. Required by upstream.",
							},
							"type": map[string]any{
								"type":    "string",
								"enum":    []string{"noul", "boolean", "choice", "score"},
								"default": "noul",
								"description": "noul/boolean → 0..1 confidence; choice → label; " +
									"score → 0..1 over the criteria keys.",
							},
							"criteria": map[string]any{
								"type":                 "object",
								"additionalProperties": map[string]any{"type": "string"},
								"description":          "label → description. Required for choice/score; keys become the legend axis.",
							},
						},
						"required": []string{"id", "instructions"},
					},
				},
			},
			"required": []string{"state", "questions"},
		},
	}
}

func main() {
	if err := serve(loadConfig(), os.Stdin, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "jev-mcp:", err)
		os.Exit(1)
	}
}

// serve runs the line-delimited JSON-RPC loop until stdin is closed.
func serve(cfg config, in io.Reader, out io.Writer) error {
	w := bufio.NewWriter(out)
	sc := bufio.NewScanner(in)
	sc.Buffer(make([]byte, 0, 64<<10), 8<<20)
	for sc.Scan() {
		line := bytes.TrimSpace(sc.Bytes())
		if len(line) == 0 {
			continue
		}
		var req rpcRequest
		if err := json.Unmarshal(line, &req); err != nil {
			writeResp(w, rpcResponse{JSONRPC: "2.0", Error: &rpcError{Code: -32700, Message: "parse error"}})
			w.Flush()
			continue
		}
		if resp, ok := handle(cfg, req); ok {
			writeResp(w, resp)
		}
		w.Flush()
	}
	return sc.Err()
}

// handle dispatches one message. ok=false means "no reply" (notifications).
func handle(cfg config, req rpcRequest) (rpcResponse, bool) {
	id := bytes.TrimSpace(req.ID)
	isNotification := len(id) == 0 || string(id) == "null"

	switch req.Method {
	case "initialize":
		return okResp(id, map[string]any{
			"protocolVersion": protocolVersion,
			"capabilities":    map[string]any{"tools": map[string]any{}},
			"serverInfo":      map[string]any{"name": serverName, "version": serverVersion},
		}), true
	case "notifications/initialized", "notifications/cancelled":
		return rpcResponse{}, false
	case "ping":
		return okResp(id, map[string]any{}), true
	case "tools/list":
		return okResp(id, map[string]any{"tools": []tool{jevTool()}}), true
	case "tools/call":
		return callTool(cfg, id, req.Params), true
	default:
		if isNotification {
			return rpcResponse{}, false
		}
		return errResp(id, -32601, "method not found: "+req.Method), true
	}
}

func callTool(cfg config, id, params json.RawMessage) rpcResponse {
	var p callParams
	if err := json.Unmarshal(params, &p); err != nil {
		return errResp(id, -32602, "invalid params: "+err.Error())
	}
	if p.Name != toolName {
		return errResp(id, -32602, "unknown tool: "+p.Name)
	}
	var args struct {
		State     string     `json:"state"`
		Questions []question `json:"questions"`
	}
	if err := json.Unmarshal(p.Arguments, &args); err != nil {
		return toolErr(id, "invalid arguments: "+err.Error())
	}
	if strings.TrimSpace(args.State) == "" {
		return toolErr(id, "state is required")
	}
	if len(args.Questions) == 0 {
		return toolErr(id, "at least one question is required")
	}
	if len(args.Questions) > maxQuestions {
		return toolErr(id, fmt.Sprintf("at most %d questions per call (got %d)", maxQuestions, len(args.Questions)))
	}
	for _, q := range args.Questions {
		if q.ID == "" || q.Instructions == "" {
			return toolErr(id, "each question needs a non-empty id and instructions")
		}
	}
	env := cfg.evaluate(context.Background(), args.State, args.Questions)
	b, err := json.Marshal(env)
	if err != nil {
		return toolErr(id, "encode envelope: "+err.Error())
	}
	return okResp(id, map[string]any{
		"content": []map[string]any{{"type": "text", "text": string(b)}},
	})
}

func okResp(id json.RawMessage, result any) rpcResponse {
	return rpcResponse{JSONRPC: "2.0", ID: id, Result: result}
}

func errResp(id json.RawMessage, code int, msg string) rpcResponse {
	return rpcResponse{JSONRPC: "2.0", ID: id, Error: &rpcError{Code: code, Message: msg}}
}

// toolErr is a tool-level failure: a successful RPC carrying isError=true.
func toolErr(id json.RawMessage, msg string) rpcResponse {
	return okResp(id, map[string]any{
		"content": []map[string]any{{"type": "text", "text": msg}},
		"isError": true,
	})
}

func writeResp(w *bufio.Writer, resp rpcResponse) {
	b, err := json.Marshal(resp)
	if err != nil {
		fmt.Fprintln(os.Stderr, "jev-mcp: marshal:", err)
		return
	}
	_, _ = w.Write(b)
	_ = w.WriteByte('\n')
}
