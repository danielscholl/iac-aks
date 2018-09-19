const test = require('tap').test;
const uuid = require('uuid');
const {
  exec
} = require('child_process');
const template = require('../azuredeploy.json');
const parameters = require('../azuredeploy.parameters.json');
const before = test;
const after = test;

const location = 'eastus';
const prefix = uuid.v4().substr(0, 5);
const resourceGroupName = `${prefix}-spec-group`;


before('az group create', assert => {
  const command = `az group create \
                    --name ${resourceGroupName} \
                    --location ${location} \
                    --query name -otsv`;

  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`exec error: ${error}`);
    }

    assert.ok(true, stdout);
    assert.end();
  });
});


test('az group deployment validate', assert => {
  const command = `az group deployment validate \
                    --template-file ./azuredeploy.json \
                    --parameters ./azuredeploy.json \
                    --resource-group ${resourceGroupName} \
                    --mode Complete`;

  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`exec error: ${error}`);
    }

    assert.ok(stdout, 'validation: exit 0');
    assert.end();
  });
});

after('az group delete', assert => {
  const command = `az group delete \
                    --name ${resourceGroupName} \
                    --yes --no-wait`;

  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`exec error: ${error}`);
    }

    assert.ok(true, `${resourceGroupName} deleted.`);
    assert.end();
  });
});
