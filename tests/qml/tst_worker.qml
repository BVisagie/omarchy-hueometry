import QtQuick
import QtTest

// The engine also runs on a WorkerScript thread, where puzzle generation and
// hints will run.
TestCase {
  name: "Worker"
  property var answer: null

  WorkerScript {
    id: worker
    source: "worker_probe.mjs"
    onMessage: (m) => answer = m
  }

  function test_engine_in_worker() {
    tryVerify(() => worker.ready, 5000)
    worker.sendMessage({ from: 0, to: 2 })
    tryVerify(() => answer !== null, 5000)
    compare(answer.accepted, true)
    compare(answer.columns, [[1], [1, 0], [0]])
  }
}
