/* A simple monitoring script for polkadot
 * Copyright 2020 MIDL.dev
 *
 * */

// Import the API
const { ApiPromise, WsProvider } = require('@polkadot/api');
const { WebClient, WebAPICallResult } = require('@slack/web-api');

const polkadotValidators = JSON.parse(process.env.POLKADOT_VALIDATORS);


async function main () {
  const provider = new WsProvider(`ws://${process.env.NODE_ENDPOINT}:9944`);
  // Create an await for the API
  const api = await ApiPromise.create({ provider });

  console.log("Validator monitor has started.");
  console.log(`It will monitor events related to the following validators: ${polkadotValidators.map(x => x['name'])}`);
  const validators = await api.query.session.validators();

  for (const validator of polkadotValidators) {
    if (validators.includes(validator["stash_account_address"])) {
      console.log(`${validator["name"]} is currently ACTIVE. The current process will alert if this changes.`);
    } else {
      console.log(`${validator["name"]} is currently NOT ACTIVE. The current process will alert if this changes.`);
    }
  }

  api.query.system.events((events) => {

    // Loop through the Vec<EventRecord>
    for (const record of events) {
      // Extract the phase, event and the event types
      const { event, phase } = record;
      const types = event.typeDef;

      if (event.section == "staking" && event.method == "StakingElection") {
        (async() => {
          var queuedKeys = await api.query.session.queuedKeys();
          var electedValidators = queuedKeys.map(x => x[0].toHuman());
          //console.log(`Staking election has happened, elected validators are ${electedValidators}`);
          console.log(`Staking election has happened.`);
          for (const validator of polkadotValidators) {
            if (electedValidators.includes(validator["stash_account_address"])) {
                var message = `${validator["name"]} is part of the next set of validators`;
                console.log(message);
                const slackWeb = new WebClient(validator["slack_token"]);
                const res = (await slackWeb.chat.postMessage({ text: message, channel: validator["slack_channel"] }));
            }
          };
        })();
      } else if (event.section == "staking" && event.method == "Slash") {
        console.log(`raw data ${event.data}`);
        console.log(`Validator ${event.data.validator} has been slashed by amount ${event.data.amount}`);
      } else if (event.section == "imOnline" && event.method == "SomeOffline") {
        var offlineValidators = event.data[0].map(x => x[0]);
        console.log(`Some validators have been found to be offline: ${offlineValidators}`);
        for (const validator of polkadotValidators) {
          if (offlineValidators.includes(validator["stash_account_address"])) {
            var message = `${validator["name"]} has been marked offline.`;
            console.log(message);
            (async() => {
              const slackWeb = new WebClient(validator["slack_token"]);
              const res = (await slackWeb.chat.postMessage({ text: message, channel: validator["slack_channel"] }));
            })();
          }
        }; 
      }
    };
  });
}

main().catch(console.error);
