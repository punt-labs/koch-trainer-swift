import CoreServices
import Foundation

if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "id" {
    print(FSEventsGetCurrentEventId())
    exit(0)
}

guard CommandLine.arguments.count >= 4,
      let since = FSEventStreamEventId(CommandLine.arguments[2]) else {
    exit(2)
}

let callback: FSEventStreamCallback = { _, _, count, eventPaths, flags, ids in
    let paths = unsafeBitCast(eventPaths, to: NSArray.self)
    for index in 0 ..< count {
        let event: [String: Any] = ["path": paths[index], "flags": flags[index], "id": ids[index]]
        guard let data = try? JSONSerialization.data(withJSONObject: event),
              let line = String(data: data, encoding: .utf8) else {
            exit(3)
        }
        print(line)
    }
    fflush(stdout)
}

let roots = Array(CommandLine.arguments.dropFirst(3)) as CFArray
let flags = FSEventStreamCreateFlags(
    kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents |
        kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer
)
guard let stream = FSEventStreamCreate(nil, callback, nil, roots, since, 0.05, flags) else {
    exit(3)
}

FSEventStreamSetDispatchQueue(stream, DispatchQueue(label: "koch.fsevents"))
guard FSEventStreamStart(stream) else { exit(4) }
fputs("READY\n", stderr)
fflush(stderr)
var command = readLine()
if command == "CUTOFF" {
    fputs("\(FSEventsGetCurrentEventId())\n", stderr)
    fflush(stderr)
    command = readLine()
}

guard command == "FLUSH" else { exit(5) }
FSEventStreamFlushSync(stream)
FSEventStreamStop(stream)
FSEventStreamInvalidate(stream)
FSEventStreamRelease(stream)
