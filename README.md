Amoveo Mining Pool
===========

This is a mining pool for the [Amoveo blockchain](https://github.com/zack-bitcoin/amoveo).

A mining pool has a server. The server runs a full node of Amoveo so that they can calculate what we should be mining on next.

A mining pool has workers. The workers all ask the server what to work on, and give their work to the server.

The server pays the worker some money.

Some of the work can be used to make blocks to pay the server.

This software is only the server. Different kinds of workers can connect to this server, if they know your ip address and the port you are running this mining pool server on. By default it uses port 8085.


=== Turning it on

```
sh start.sh
```

Then to turn it off:

```
halt().
```