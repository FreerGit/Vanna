# Vanna
A distributed KV store using Viewstamped Replication (VSR), the implemenation is based on the [Viestamped Replication Revisited](https://pmg.csail.mit.edu/papers/vr-revisited.pdf) paper



make sure replica <-> replica comms work

create prepare

create prepareOk

create reply

at this point the distributed KV store _should_ work under _normal_ conditions

https://blog.brunobonacci.com/2018/07/15/viewstamped-replication-explained/
https://dspace.mit.edu/bitstream/handle/1721.1/71763/MIT-CSAIL-TR-2012-021.pdf?sequence=1&isAllowed=y

## TBD
**What protocol should replicas <-> clients speak?**
* An option is json, slow but simple and all languages has good eco support.
* Simply use bin_prot, downside of ocaml only.
* Another option is protobuf, a bif faster than json and decent eco support.

**_IF_ I go down the multiple client route, do I write it in C to let others wrap it?**
* I would like a C99 client anyway so I guess it make sense.


## Things to ponder upon

TODO uninstall forticlient and thinlinc

### Client id
Right now there can be {0..uint32_max} clients, the client must keep track of the client id from the response. There is no way to remove clients from the table at this point, I could set a timeout on each entry? That would require the client to also know abou that timeout however, since it would need to send a new Join mesasge to get a new id. 

I could also just have the client generate a uuid and then do a join, if the uuid already exist (highly unlikely), then just generate a new one.

## Clients
have a unique id (client_id), and they communcate only with the primary.

If a client contacts a replica which is not the primar, the replica drops the request and returns an errors message (talk to the primary dummy)

Each client can only send one requst at the time, and each request has a request number, which is monotonically increasing (ocaml int should be fine)

The client prepares a REQUEST message which contains client_id, requst_num and op

## Primary
only processes the request if its STATUS is NORMAL, otherwise, drop and return err (try again)

upon request, look into client table and see if request num is present (err) and if the request_num is greater than last (if not, drop and resend last reponse present in table)

if its a new request, the primary increases the op_num, it appends the requested op to its op_log and updates the client_table with the new request

Then it needs to notify all replicas so create a PREPARE (view_num, op_num, commit_num, message) and send to all replicas

## Three sub protocols
**Normal case processing of user requests.**

**View changes to selsect a new primary**

**Recovery of a failed replica so that it can rejoin the group.**

## Section 4 - Fixed number of replicas

The replica which has lowest IP is replica 1, the primary is choosen round robin, starting with replica 1


## Section 5 & 6 - Optimizations

## Section 7 - Reconfiguration (variable number of replicas)
