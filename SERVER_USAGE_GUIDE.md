# API Usage Guide

Reference for the Parallax Connect server API.

## Base URL

- Local: `http://<your-ip>:8000`
- Cloud: `https://<ngrok-subdomain>.ngrok.io`

## Authentication

If password protection is enabled, include the header:

```
x-password: your_password
```

## Endpoints

### Health Check

```http
GET /healthz
```

No authentication required. Returns `{"status": "ok"}`.

### Server Status

```http
GET /status
```

Returns server and Parallax connectivity status.

### Available Models

```http
GET /models
```

Returns list of available models and the currently active model.

### Server Info

```http
GET /info
```

Returns server capabilities (VRAM, context window, etc.).

### Chat (Synchronous)

```http
POST /chat
Content-Type: application/json

{
  "prompt": "Your message here",
  "system_prompt": "Optional system instructions",
  "messages": [],
  "max_tokens": 8192,
  "temperature": 0.7,
  "top_p": 0.9,
  "top_k": -1
}
```

Response:

```json
{
  "response": "AI response text",
  "metadata": {
    "usage": {
      "prompt_tokens": 15,
      "completion_tokens": 127,
      "total_tokens": 142
    },
    "timing": {
      "duration_ms": 2340,
      "duration_seconds": 2.34
    },
    "model": "model-name"
  }
}
```

### Chat (Streaming)

```http
POST /chat/stream
Content-Type: application/json
```

Same request body as `/chat`. Returns Server-Sent Events:

```
data: {"type": "thinking", "content": "..."}
data: {"type": "content", "content": "..."}
data: {"type": "done", "metadata": {...}}
```

## Request Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | string | required | User message |
| `system_prompt` | string | null | System instructions |
| `messages` | array | null | Conversation history |
| `max_tokens` | int | 8192 | Max response length |
| `temperature` | float | 0.7 | Creativity (0.0-2.0) |
| `top_p` | float | 0.9 | Nucleus sampling |
| `top_k` | int | -1 | Top-k sampling (-1 = disabled) |

### Multi-turn Conversations

Include previous messages in the `messages` array:

```json
{
  "prompt": "What about Python?",
  "messages": [
    {"role": "user", "content": "What programming languages do you know?"},
    {"role": "assistant", "content": "I can help with many languages..."}
  ]
}
```

## Flutter Integration

### Chat Response Model

```dart
class ChatResponse {
  final String response;
  final ResponseMetadata? metadata;

  ChatResponse({required this.response, this.metadata});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      response: json['response'],
      metadata: json['metadata'] != null
          ? ResponseMetadata.fromJson(json['metadata'])
          : null,
    );
  }
}

class ResponseMetadata {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double durationSeconds;
  final String model;

  ResponseMetadata({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.durationSeconds,
    required this.model,
  });

  factory ResponseMetadata.fromJson(Map<String, dynamic> json) {
    final usage = json['usage'];
    final timing = json['timing'];
    return ResponseMetadata(
      promptTokens: usage['prompt_tokens'],
      completionTokens: usage['completion_tokens'],
      totalTokens: usage['total_tokens'],
      durationSeconds: timing['duration_seconds'].toDouble(),
      model: json['model'],
    );
  }
}
```

### AI Settings Presets

```dart
class AISettings {
  final double temperature;
  final double topP;
  final int maxTokens;

  const AISettings({
    this.temperature = 0.7,
    this.topP = 0.9,
    this.maxTokens = 8192,
  });

  // Presets
  static const creative = AISettings(temperature: 1.2, topP: 0.95);
  static const balanced = AISettings(temperature: 0.7, topP: 0.9);
  static const precise = AISettings(temperature: 0.3, topP: 0.5);

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'top_p': topP,
    'max_tokens': maxTokens,
  };
}
```

### API Call Example

```dart
Future<ChatResponse> sendMessage(String prompt, AISettings settings) async {
  final response = await http.post(
    Uri.parse('$baseUrl/chat'),
    headers: {
      'Content-Type': 'application/json',
      if (password != null) 'x-password': password!,
    },
    body: jsonEncode({
      'prompt': prompt,
      ...settings.toJson(),
    }),
  );

  return ChatResponse.fromJson(jsonDecode(response.body));
}
```

## Testing with cURL

```bash
# Basic request
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello"}'

# With password
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -H "x-password: your_password" \
  -d '{"prompt": "Hello"}'

# With parameters
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a poem", "temperature": 1.2, "max_tokens": 500}'
```

## Streaming with SSE

The `/chat/stream` endpoint returns events in this format:

- `thinking`: Model's reasoning process (from `<think>` tags)
- `content`: Actual response content
- `done`: Stream complete with metadata
- `error`: Error occurred

Handle in Flutter with `http` package's streaming or use `dio` with response type `ResponseType.stream`.
