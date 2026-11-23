import * as R from "../../qml/Hueometry/js/rules.mjs";

WorkerScript.onMessage = function (m) {
  const r = R.play(R.newGame(2, 2, [[0, 1], [1, 0], []]), m.from, m.to);
  WorkerScript.sendMessage({ accepted: r.accepted, columns: R.view(r.game).columns });
};
