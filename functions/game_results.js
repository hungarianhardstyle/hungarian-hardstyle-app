'use strict';

const { buildRankedGameEntries } = require('./game_rewards');

function buildGameLeaderboard(entries) {
  const ranked = buildRankedGameEntries(entries);

  return ranked.map((entry, index) => ({
    rank: index + 1,
    displayName: entry.displayName,
    correctAnswers: entry.correctAnswers,
    totalAnswers: entry.totalAnswers,
    percent: Math.round((entry.correctAnswers / entry.totalAnswers) * 100),
  }));
}

module.exports = { buildGameLeaderboard };
