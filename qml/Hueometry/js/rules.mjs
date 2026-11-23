// The one door between the interface and the Bend rules engine.
//
// Every game state the interface shows comes from here, and every change to
// it goes through engine.mjs. This file only converts between JavaScript
// arrays and Bend values; it decides no rule itself.
//
// Boards are arrays of columns; a column is an array of colour numbers from
// the TOP bead down, as in the engine. A game is an opaque engine value:
// keep it, pass it back, and read it with view().

import * as E from "./engine.mjs";

const NIL = { $: "Nil" };

export function list(items) {
  let l = NIL;
  for (let i = items.length - 1; i >= 0; i--) l = { $: "Con", head: items[i], tail: l };
  return l;
}

export function array(l) {
  const out = [];
  while (l.$ === "Con") {
    out.push(l.head);
    l = l.tail;
  }
  return out;
}

export function toBoard(columns) {
  return list(columns.map(list));
}

export function fromBoard(b) {
  return array(b).map(array);
}

const REASONS = {
  NoSuchColumn: "no-such-column",
  SameColumn: "same-column",
  EmptySource: "empty-source",
  FullTarget: "full-target",
};

// A new game from a board (columns top first).
export function newGame(colours, cap, columns) {
  return E.new_game(colours, cap, toBoard(columns));
}

// Asks the engine to move the top bead of column `from` onto column `to`.
// Answers { accepted, game, reason }: the game is unchanged when refused.
export function play(game, from, to) {
  if (!Number.isInteger(from) || !Number.isInteger(to) || from < 0 || to < 0) {
    return { accepted: false, game, reason: "no-such-column" };
  }
  const out = E.play(game, from, to);
  if (out.$ === "Accepted") return { accepted: true, game: out.game, reason: null };
  return { accepted: false, game, reason: REASONS[out.reason.$] };
}

export function undo(game) {
  return E.undo(game);
}

export function restart(game) {
  return E.restart(game);
}

export function solved(game) {
  return E.solved(game) === true;
}

export function moves(game) {
  return E.moves(game);
}

export function targets(game, column) {
  if (!Number.isInteger(column) || column < 0) return [];
  return array(E.targets(game, column));
}

// The moves played so far, oldest first, as { from, to }.
export function history(game) {
  return array(game.history).reverse().map((m) => ({ from: m.from, to: m.to }));
}

// Replays moves ({ from, to }, oldest first) from the game's current board.
export function replay(game, moveList) {
  return E.replay(game, list(moveList.map((m) => ({ $: "Mv", from: m.from, to: m.to }))));
}

// Everything the interface needs to draw a game.
export function view(game) {
  return {
    colours: game.colours,
    cap: game.cap,
    columns: fromBoard(game.board),
    start: fromBoard(game.start),
    moves: moves(game),
    solved: solved(game),
  };
}
