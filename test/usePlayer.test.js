import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildDisplayedSongs,
  createPlaybackSnapshot,
  resolveVisiblePlaybackState,
} from '../src/composables/usePlayer.js';

function makeSong(path, title = path) {
  return {
    path,
    file_name: `${title}.mp3`,
    title,
    artist: '',
    album: '',
    duration: 180,
  };
}

test('从全部歌曲开始播放后切换到单文件夹，播放队列仍保持原始队列', () => {
  const folderA = {
    path: '/music/A',
    name: 'A',
    songs: [makeSong('/music/A/1.mp3', 'A1'), makeSong('/music/A/2.mp3', 'A2')],
  };
  const folderB = {
    path: '/music/B',
    name: 'B',
    songs: [makeSong('/music/B/1.mp3', 'B1')],
  };

  const initialView = buildDisplayedSongs([folderA, folderB], null);
  const snapshot = createPlaybackSnapshot(initialView.displayedSongs, 1);
  const filteredView = buildDisplayedSongs([folderA, folderB], 1);
  const visibleState = resolveVisiblePlaybackState(filteredView.displayedSongs, snapshot.currentSong);

  assert.deepEqual(snapshot.playbackQueue.map(song => song.path), [
    '/music/A/1.mp3',
    '/music/A/2.mp3',
    '/music/B/1.mp3',
  ]);
  assert.equal(snapshot.currentSong.path, '/music/A/2.mp3');
  assert.equal(visibleState.currentVisibleIndex, null);
  assert.equal(visibleState.isCurrentSongVisible, false);
});

test('播放中删除文件夹后，现有播放队列仍可继续，且当前歌曲可以不在可见列表中', () => {
  const removableFolder = {
    path: '/music/remove',
    name: 'remove',
    songs: [makeSong('/music/remove/1.mp3', 'R1')],
  };
  const keepFolder = {
    path: '/music/keep',
    name: 'keep',
    songs: [makeSong('/music/keep/1.mp3', 'K1')],
  };

  const initialView = buildDisplayedSongs([removableFolder, keepFolder], null);
  const snapshot = createPlaybackSnapshot(initialView.displayedSongs, 0);
  const afterRemoval = buildDisplayedSongs([keepFolder], null);
  const visibleState = resolveVisiblePlaybackState(afterRemoval.displayedSongs, snapshot.currentSong);

  assert.deepEqual(snapshot.playbackQueue.map(song => song.path), [
    '/music/remove/1.mp3',
    '/music/keep/1.mp3',
  ]);
  assert.equal(snapshot.currentSong.path, '/music/remove/1.mp3');
  assert.equal(visibleState.currentVisibleIndex, null);
  assert.equal(visibleState.isCurrentSongVisible, false);
});

test('当前歌曲不在过滤结果中时，显式返回不可见状态而不是 -1', () => {
  const displayedSongs = [makeSong('/music/A/1.mp3', 'A1')];
  const currentSong = makeSong('/music/B/2.mp3', 'B2');

  const visibleState = resolveVisiblePlaybackState(displayedSongs, currentSong);

  assert.equal(visibleState.currentVisibleIndex, null);
  assert.equal(visibleState.isCurrentSongVisible, false);
});


test('重复路径歌曲从后一个副本开始播放时，保留对应的队列与可见索引', () => {
  const displayedSongs = [
    makeSong('/music/shared.mp3', 'first copy'),
    makeSong('/music/shared.mp3', 'second copy'),
    makeSong('/music/unique.mp3', 'unique'),
  ];

  const snapshot = createPlaybackSnapshot(displayedSongs, 1);
  const visibleState = resolveVisiblePlaybackState(displayedSongs, snapshot.currentSong, snapshot.currentQueueIndex);

  assert.equal(snapshot.currentSong.title, 'second copy');
  assert.equal(snapshot.currentQueueIndex, 1);
  assert.equal(snapshot.currentVisibleIndex, 1);
  assert.equal(visibleState.currentVisibleIndex, 1);
  assert.equal(visibleState.isCurrentSongVisible, true);
});
