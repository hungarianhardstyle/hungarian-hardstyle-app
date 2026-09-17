'use strict';

function gameRewardPoints(game, correctAnswers, totalAnswers) {
  const type = String(game?.type || '');
  if (type === 'hardstyle_quiz' || type === 'festival_quiz' || type === 'hungarian_hardstyle_quiz') {
    const percent = totalAnswers > 0 ? Math.floor((correctAnswers / totalAnswers) * 100) : 0;
    const band = Array.isArray(game.reward_bands)
      ? game.reward_bands.find((item) => percent >= Number(item.min || 0) && percent <= Number(item.max || 0))
      : null;
    return Math.max(0, Number(band?.points || 0));
  }
  return correctAnswers === totalAnswers && totalAnswers > 0 ? Math.max(0, Number(game.reward_points || 0)) : 0;
}

function buildRankedGameEntries(entries) {
  return entries
    .filter((entry) => entry.displayName && entry.totalAnswers > 0)
    .map((entry) => ({
      uid: String(entry.uid || '').trim(),
      displayName: String(entry.displayName).trim(),
      correctAnswers: Math.max(0, Number(entry.correctAnswers) || 0),
      totalAnswers: Math.max(1, Number(entry.totalAnswers) || 1),
      submittedAt: Math.max(0, Number(entry.submittedAt) || 0),
    }))
    .sort((a, b) => {
      const percentDifference = b.correctAnswers / b.totalAnswers - a.correctAnswers / a.totalAnswers;
      if (percentDifference) return percentDifference;
      if (b.correctAnswers !== a.correctAnswers) return b.correctAnswers - a.correctAnswers;
      if (a.submittedAt !== b.submittedAt) return a.submittedAt - b.submittedAt;
      return a.displayName.localeCompare(b.displayName, 'hu');
    })
    .map((entry, index) => ({ ...entry, rank: index + 1 }));
}

module.exports = { gameRewardPoints, buildRankedGameEntries };
