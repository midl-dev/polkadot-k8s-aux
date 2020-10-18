/* A simple one-shot payout script for Polkadot
 * Copyright 2020 MIDL.dev
 *
 * This script requires a payout account with dust money to pay for transaction fees to call the payout extrinsic.
 *
 * All inputs come from environment variables.
 *
 * The script queries the current era. It then verifies that:
 *
 *  * the previous era has not been paid yet
 *  * the validator was active in the previous era
 *
 *  When these conditions are met, it sends the payout extrinsic and exits. */

// Import the API
const { ApiPromise, WsProvider } = require('@polkadot/api');
const { Keyring } = require('@polkadot/keyring');

async function main () {
  const provider = new WsProvider(`ws://${process.env.NODE_ENDPOINT}:9944`);
  // Create our API
  const api = await ApiPromise.create({ provider });

  // Constuct the keying
  const keyring = new Keyring({ type: 'sr25519' });

  // Add the payout account to our keyring
  const payoutKey = keyring.addFromUri(process.env.PAYOUT_ACCOUNT_MNEMONIC);

  const [currentEra] = await Promise.all([
    api.query.staking.currentEra()
  ]);


  for (const stash_account of process.env.STASH_ACCOUNT_ADDRESS.split(",")) {
    var controller_address = await api.query.staking.bonded(stash_account);
    var controller_ledger = await api.query.staking.ledger(controller_address.toString());
    claimed_eras = controller_ledger.toHuman().claimedRewards.map(x => parseInt(x.replace(',','')));
    console.log(`Payout for validator stash ${stash_account} has been claimed for eras: ${claimed_eras}`);

    if (claimed_eras.includes(currentEra - 1)) {
      console.log(`Payout for validator stash ${stash_account} for era ${currentEra - 1} has already been issued, exiting`);
      continue;
    }

    var exposure_for_era = await api.query.staking.erasStakers(currentEra - 1, stash_account);
    if (exposure_for_era.total == 0) {
      console.log(`Stash ${stash_account} was not in the active validator set for era ${currentEra - 1}, not payout can be made, exiting`);
      continue;
    }

    console.log(`Issuing payoutStakers extrinsic from address ${process.env.PAYOUT_ACCOUNT_ADDRESS} for validator stash ${stash_account} for era ${currentEra - 1}`);

    // Create, sign and send the payoutStakers extrinsic
    var unsub = await api.tx.staking.payoutStakers(stash_account, currentEra - 1).signAndSend(payoutKey, ({ events = [], status }) => {
      console.log('Transaction status:', status.type);

      if (status.isInBlock) {
        console.log('Included at block hash', status.asInBlock.toHex());
        console.log('Events:');

        events.forEach(({ event: { data, method, section }, phase }) => {
          console.log('\t', phase.toString(), `: ${section}.${method}`, data.toString());
        });
      } else if (status.isFinalized) {
        console.log('Finalized block hash', status.asFinalized.toHex());
      } else if (status.isError) {
        console.error('Errored out in block hash', status.asFinalized.toHex());
        process.exit(1);
      }
    });
  }
  console.log("Exiting");
  process.exit(0);
}

main().catch(console.error);
