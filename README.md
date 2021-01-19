Polkadot-k8s auxiliary cluster
==============================

This is the second part of the polkadot-k8s project.

This is a set of terraform and kubernetes code to deply a tezos node in k8s that performs the following operations:

* monitors validation operations
* sends payouts

Monitoring
----------

In addition to internal monitoring of the main validation cluster, it is recommended to monitor the validation operations from a node that is completely separated from the validation infrastructure. A good option is to set up a completely separate Kubernetes cluster, and run monitoring on it, this way it is administratively separated from the main validating node.

Payout-cron
-----------

This kubernetes cronjob triggers the payout extrinsic regularly.
