<?php

namespace App\Http\Controllers;

use App\Models\Candidate;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class CandidateController extends Controller
{
    public function index()
    {
        $candidates = Candidate::all()->map(function (Candidate $c) {
            $c->symbol = $this->normalizeSymbolForApi($c->symbol);

            return $c;
        });

        return response()->json($candidates);
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'position' => 'required|string|max:255',
            'symbol' => 'nullable|image|mimes:jpg,jpeg,png|max:2048',
        ]);

        $imageBase64 = null;

        if ($request->hasFile('symbol')) {
            $file = $request->file('symbol');
            $imageData = file_get_contents($file->getRealPath());
            $base64 = base64_encode($imageData);
            $mime = $file->getMimeType() ?: 'image/png';
            $imageBase64 = 'data:'.$mime.';base64,'.$base64;
        }

        $candidate = Candidate::create([
            'name' => $request->name,
            'position' => $request->position,
            'symbol' => $imageBase64,
            'votes' => 0,
        ]);

        return response()->json([
            'message' => 'Candidate added successfully',
            'data' => $candidate,
        ]);
    }

    /**
     * Always expose a data-uri so mobile clients can use MemoryImage.
     * Supports legacy rows: relative storage paths, full URLs, raw base64.
     */
    private function normalizeSymbolForApi(?string $raw): ?string
    {
        if ($raw === null || $raw === '') {
            return null;
        }

        $raw = trim($raw);

        if (Str::startsWith($raw, 'data:')) {
            return $this->sanitizeDataUri($raw);
        }

        if (Str::startsWith($raw, 'http://') || Str::startsWith($raw, 'https://')) {
            return $this->tryFetchRemoteAsDataUri($raw);
        }

        $path = ltrim($raw, '/');
        if ($path !== '' && ! Str::contains($path, '..')) {
            if (Storage::disk('public')->exists($path)) {
                $bytes = Storage::disk('public')->get($path);
                $mime = $this->guessMimeFromPath($path);

                return 'data:'.$mime.';base64,'.base64_encode($bytes);
            }
        }

        if (strlen($raw) >= 32 && preg_match('/^[A-Za-z0-9+\/=\s_-]+$/', $raw)) {
            $clean = preg_replace('/\s+/', '', $raw) ?? '';
            $normalized = strtr($clean, '-_', '+/');
            $decoded = base64_decode($normalized, true);
            if ($decoded !== false && strlen($decoded) > 0) {
                return 'data:image/png;base64,'.base64_encode($decoded);
            }
        }

        return null;
    }

    private function sanitizeDataUri(string $dataUri): string
    {
        $comma = strpos($dataUri, ',');
        if ($comma === false) {
            return $dataUri;
        }
        $head = substr($dataUri, 0, $comma);
        $payload = substr($dataUri, $comma + 1);
        $payload = preg_replace('/\s+/', '', $payload) ?? '';

        return $head.','.$payload;
    }

    private function guessMimeFromPath(string $path): string
    {
        $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));

        return match ($ext) {
            'jpg', 'jpeg' => 'image/jpeg',
            'gif' => 'image/gif',
            'webp' => 'image/webp',
            default => 'image/png',
        };
    }

    private function tryFetchRemoteAsDataUri(string $url): ?string
    {
        try {
            $ctx = stream_context_create([
                'http' => ['timeout' => 5],
                'https' => ['timeout' => 5],
            ]);
            $data = @file_get_contents($url, false, $ctx);
            if ($data === false || $data === '') {
                return null;
            }
            $mime = 'image/png';
            if (function_exists('finfo_open')) {
                $f = finfo_open(FILEINFO_MIME_TYPE);
                if ($f) {
                    $detected = finfo_buffer($f, $data);
                    finfo_close($f);
                    if (is_string($detected) && str_starts_with($detected, 'image/')) {
                        $mime = $detected;
                    }
                }
            }

            return 'data:'.$mime.';base64,'.base64_encode($data);
        } catch (\Throwable) {
            return null;
        }
    }
}
