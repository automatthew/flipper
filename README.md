## Flipper

Flipper is an interactive tool for "config-stamping" the results of
shell commands.  It was developed specifically for use in load testing,
but it can profitably be used in any other situation where a complex
configuration should be tracked.

The basic idea:  Flipper maintains a nested JSON structure representing
your current environment.  If you're load testing, you tell Flipper
any and all relevant details about the configuration of the target
service and the testing tools.  This tedious process is made easier by
tab completion, and the results are saved for you between sessions.

Within the Flipper shell, you can pass commands to the shell by prefixing
them with '!', much as in Vim.  When you want to store the results of a shell
command (both STDIN and STDOUT), prefix the command with 'run' instead.  After
the command has completed, Flipper asks whether you want to save the results
to file.  If so, it saves a JSON file containing the current configuration and
the result data.

So long as you are diligent about updating the configuration data whenever
you make changes in real life, you end up with config-stamped reports that
can be useful in troubleshooting or optimizing a service.

## Example session:

    moldbug:~ $ cd projects/flipper/
    moldbug:~/projects/flipper $ bin/flipper

    <3: help
    * Available commands: ! delete help quit reload run save show
    * Set values with:  foo.bar = whitespace is ok
    * Tab completion works for commands and config keys
    <3: show
    {
      "tester": {
        "version": 0.1,
        "software": "dolphin"
      },
      "human": "anonymous coward",
      "target": {
      }
    }
    <3: tester.software = httperf
    <3: human = Matthew King
    <3: show
    {
      "tester": {
        "version": 0.1,
        "software": "httperf"
      },
      "human": "Matthew King",
      "target": {
      }
    }
    <3: target.location = ec2 west
    <3: target.boxes.proxy.type = large
    <3: target.boxes.proxy.software = haproxy
    <3: target.boxes.proxy.version = 1.4.18
    <3: show target
    {
      "location": "ec2 west",
      "boxes": {
        "proxy": {
          "version": "1.4.18",
          "type": "large",
          "software": "haproxy"
        }
      }
    }
    <3: save
    <3: target.boxes.http.type = medium
    <3: target.boxes.http.software = Shark HTTP Server
    <3: target.boxes.http.version = 0.1.4
    <3: target.boxes.http.count = 4
    <3: show
    {
      "tester": {
        "version": 0.1,
        "software": "httperf"
      },
      "human": "Matthew King",
      "target": {
        "location": "ec2 west",
        "boxes": {
          "proxy": {
            "version": "1.4.18",
            "type": "large",
            "software": "haproxy"
          },
          "http": {
            "count": "4",
            "version": "0.1.4",
            "type": "medium",
            "software": "Shark HTTP Server"
          }
        }
      }
    }
    <3: run httperf --server=localhost --port=1337 --uri=/ --rate=30  --num-conns=50
      httperf: warning: open file limit > FD_SETSIZE; limiting max. # of open files to FD_SETSIZE
      httperf --client=0/1 --server=localhost --port=1337 --uri=/ --rate=30 --send-buffer=4096 --recv-buffer=16384 --num-conns=50 --num-calls=1
      Maximum connect burst length: 1

      Total: connections 50 requests 50 replies 50 test-duration 1.640 s

      Connection rate: 30.5 conn/s (32.8 ms/conn, <=1 concurrent connections)
      Connection time [ms]: min 0.8 avg 2.1 max 7.3 median 1.5 stddev 2.0
      Connection time [ms]: connect 0.1
      Connection length [replies/conn]: 1.000

      Request rate: 30.5 req/s (32.8 ms/req)
      Request size [B]: 62.0

      Reply rate [replies/s]: min 0.0 avg 0.0 max 0.0 stddev 0.0 (0 samples)
      Reply time [ms]: response 1.9 transfer 0.0
      Reply size [B]: header 118.0 content 68.0 footer 0.0 (total 186.0)
      Reply status: 1xx=0 2xx=50 3xx=0 4xx=0 5xx=0

      CPU time [s]: user 0.45 system 1.16 (user 27.6% system 70.9% total 98.6%)
      Net I/O: 7.4 KB/s (0.1*10^6 bps)

      Errors: total 0 client-timo 0 socket-timo 0 connrefused 0 connreset 0
      Errors: fd-unavail 0 addrunavail 0 ftab-full 0 other 0

    Store results? (y/N) y
    Stored results in /Users/mking/projects/flipper/flipper/0001.json

    <3: show tester
    {
      "command": " httperf --server=localhost --port=1337 --uri=/ --rate=30  --num-conns=50",
      "version": 0.1,
      "software": "httperf"
    }
    <3: tester.command = httperf --server=localhost --port=1337 --uri=/ --rate=30  --num-conns=10
    <3: run
    httperf --server=localhost --port=1337 --uri=/ --rate=30  --num-conns=50
      httperf: warning: open file limit > FD_SETSIZE; limiting max. # of open files to FD_SETSIZE
      httperf --client=0/1 --server=localhost --port=1337 --uri=/ --rate=30 --send-buffer=4096 --recv-buffer=16384 --num-conns=10 --num-calls=1
      Maximum connect burst length: 1

      Total: connections 10 requests 10 replies 10 test-duration 0.314 s

      Connection rate: 31.9 conn/s (31.4 ms/conn, <=1 concurrent connections)
      Connection time [ms]: min 0.9 avg 3.2 max 13.5 median 1.5 stddev 4.0
      Connection time [ms]: connect 0.1
      Connection length [replies/conn]: 1.000

      Request rate: 31.9 req/s (31.4 ms/req)
      Request size [B]: 62.0

      Reply rate [replies/s]: min 0.0 avg 0.0 max 0.0 stddev 0.0 (0 samples)
      Reply time [ms]: response 3.1 transfer 0.0
      Reply size [B]: header 118.0 content 68.0 footer 0.0 (total 186.0)
      Reply status: 1xx=0 2xx=10 3xx=0 4xx=0 5xx=0

      CPU time [s]: user 0.08 system 0.22 (user 27.1% system 70.1% total 97.2%)
      Net I/O: 7.7 KB/s (0.1*10^6 bps)

      Errors: total 0 client-timo 0 socket-timo 0 connrefused 0 connreset 0
      Errors: fd-unavail 0 addrunavail 0 ftab-full 0 other 0

    Store results? (y/N) y
    Stored results in /Users/mking/projects/flipper/flipper/0002.json

    <3: !ls flipper/
      0001.json
      0002.json
      _base.json
      _comp.json
    <3: quit

