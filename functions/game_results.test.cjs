'use strict';

const assert = require('node:assert/strict');
const { buildGameLeaderboard } = require('./game_results');

const results = buildGameLeaderboard([
  { displayName: 'Béla', correctAnswers: 3, totalAnswers: 4, submittedAt: 20 },
  { displayName: 'Anna', correctAnswers: 4, totalAnswers: 4, submittedAt: 30 },
  { displayName: 'Csaba', correctAnswers: 3, totalAnswers: 4, submittedAt: 10 },
]);

assert.deepEqual(results.map(({ rank, displayName, percent }) => [rank, displayName, percent]), [
  [1, 'Anna', 100],
  [2, 'Csaba', 75],
  [3, 'Béla', 75],
]);
console.log('game results leaderboard tests passed');
