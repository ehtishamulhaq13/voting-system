<?php

namespace App\Http\Controllers;

use App\Models\Candidate;
use App\Models\Vote;
use App\Models\VotingSetting;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class AdminController extends Controller
{
    public function setVotingTime(Request $request)
    {
        $request->validate([
            'start_time' => 'required|date',
            'end_time' => 'required|date|after:start_time',
        ]);

        // Treat incoming admin-selected time as Asia/Karachi and store as local datetime.
        // DB stores datetimes without timezone, so we keep them in the business timezone.
        $startTime = Carbon::parse($request->start_time, 'Asia/Karachi')->timezone('Asia/Karachi');
        $endTime = Carbon::parse($request->end_time, 'Asia/Karachi')->timezone('Asia/Karachi');

        $setting = VotingSetting::first();

        if ($setting) {
            $setting->update([
                'start_time' => $startTime,
                'end_time' => $endTime,
            ]);
        } else {
            VotingSetting::create([
                'start_time' => $startTime,
                'end_time' => $endTime,
            ]);
        }

        return response()->json([
            'message' => 'Voting time updated',
            'start_time' => $startTime->toIso8601String(),
            'end_time' => $endTime->toIso8601String(),
        ]);
    }

    public function clearElection()
    {
        DB::transaction(function () {
            $symbols = Candidate::query()
                ->whereNotNull('symbol')
                ->pluck('symbol');

            Vote::query()->delete();
            Candidate::query()->delete();
            VotingSetting::query()->delete();

            foreach ($symbols as $symbol) {
                if (! is_string($symbol) || $symbol === '') {
                    continue;
                }
                // Symbols are usually base64 in DB; only delete real storage paths.
                if (str_starts_with($symbol, 'data:') || str_starts_with($symbol, 'http://') || str_starts_with($symbol, 'https://')) {
                    continue;
                }
                $path = ltrim($symbol, '/');
                if ($path !== '' && ! str_contains($path, '..')) {
                    Storage::disk('public')->delete($path);
                }
            }
        });

        return response()->json([
            'message' => 'All candidates, votes, and timing settings cleared'
        ]);
    }
}