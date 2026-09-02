<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Default admin for local / Railway (change password in production).
     *
     * Email: admin@voting.test
     * Password: Admin123!
     */
    public function run(): void
    {
        // Remove legacy broken admin row (invalid email format).
        User::query()->where('email', 'CallmeEthi.com')->delete();

        User::updateOrCreate(
            ['email' => 'admin@voting.test'],
            [
                'name' => 'Admin',
                'password' => Hash::make('Admin123!'),
                'role' => 'admin',
            ]
        );
    }
}
