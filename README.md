# Vanna
A distributed KV store using Viewstamped Replication


https://blog.brunobonacci.com/2018/07/15/viewstamped-replication-explained/
https://dspace.mit.edu/bitstream/handle/1721.1/71763/MIT-CSAIL-TR-2012-021.pdf?sequence=1&isAllowed=y


# Clients
have a unique id (client_id), and they communcate only with the primary.

If a client contacts a replica which is not the primar, the replica drops the request and returns an errors message (talk to the primary dummy)

Each client can only send one requst at the time, and each request has a request number, which is monotonically increasing (ocaml int should be fine)

The client prepares a REQUEST message which contains client_id, requst_num and op

# Primary
only processes the request if its STATUS is NORMAL, otherwise, drop and return err (try again)

upon request, look into client table and see if request num is present (err) and if the request_num is greater than last (if not, drop and resend last reponse present in table)

if its a new request, the primary increases the op_num, it appends the requested op to its op_log and updates the client_table with the new request

Then it needs to notify all replicas so create a PREPARE (view_num, op_num, commit_num, message) and send to all replicas

# Replica

