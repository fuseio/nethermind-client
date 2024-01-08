# Fuse Nethermind Client Docs

This projects builds a customized version of the nethermind client with Fuse Network modifications. Those include the integrations with the Fuse SparkNet

Since 08.2022 Fuse moved from OE client to Nethermind. To bootstrap your own Fuse (Spark) node on Nethermind client you could use `quickstart.sh` script.

&nbsp;

## Download

`wget -O quickstart.sh https://raw.githubusercontent.com/fuseio/fuse-network/master/nethermind/quickstart.sh`

&nbsp;

## Gain needed permissions

`chmod 755 quickstart.sh`

&nbsp;

## Run

`./quickstart.sh -r [node_role] -n [network_name] -k [node_key]`

&nbsp;

## Run node for Fuse (Mainnet)

`./quickstart.sh -r node -n fuse -k fusenet-node`

&nbsp;

## Run bootnode for Spark (Testnet)

`./quickstart.sh -r bootnode -n spark -k fusenet-spark-bootnode`

Note:
`quickstart.sh` supports next Linux / Unix based distributions: Ubuntu, Debian, Fedora, CentOS, RHEL.

Usage:
`./quickstart.sh [-r|-n|-k||-v|-h|-u|-m]`

Options:

-r Specify needed node role. Available next roles: 'node', 'bootnode', 'explorer'

-n Network (mainnet or testnet). Available next values: 'fuse' and 'spark'

-k Node key name for https://health.fuse.io. Example: 'my-own-fuse-node'

-v Script version

-u Unjail a node (Validator only)

-m Flag a node for maintenance (Validator only)

-h Help page

&nbsp;

## Examples

### Unjail a node

`./quickstart.sh -u`

### Flag a node for maintenance

`./quickstart.sh -m`

&nbsp;

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md)
