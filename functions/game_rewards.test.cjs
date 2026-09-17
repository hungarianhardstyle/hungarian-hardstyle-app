'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const { gameRewardPoints, buildRankedGameEntries } = require('./game_rewards');

assert.equal(
  gameRewardPoints(
    {
      type: 'hardstyle_quiz',
      reward_bands: [{ min: 50, max: 100, points: 12 }],
    },
    3,
    4,
  ),
  12,
);
assert.equal(gameRewardPoints({ type: 'timeline', reward_points: 20 }, 1, 1), 20);
assert.equal(gameRewardPoints({ type: 'timeline', reward_points: 20 }, 0, 1), 0);
assert.equal(
  buildRankedGameEntries([
    {
      uid: 'later',
      displayName: 'Zed',
      correctAnswers: 4,
      totalAnswers: 4,
      submittedAt: 2,
    },
    {
      uid: 'first',
      displayName: 'Ada',
      correctAnswers: 4,
      totalAnswers: 4,
      submittedAt: 1,
    },
  ])[0].uid,
  'first',
);

const source = fs.readFileSync(require.resolve('./index'), 'utf8');
const submitSection = source.slice(
  source.indexOf('exports.submitGameAttempt'),
  source.indexOf('async function finalizeClosedGameRewards'),
);
assert.doesNotMatch(submitSection, /await awardAchievementPoints/);
assert.match(source, /exports\.finalizeClosedGameRewards = onSchedule/);
assert.match(source, /await finalizeClosedGameRewards\(game\)/);
console.log('game reward finalization tests passed');
