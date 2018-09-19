require('tap').mochaGlobals();
const should = require('should');

const template = require('../azuredeploy.json');
const parameters = require('../azuredeploy.parameters.json');

describe('iac-aks', () => {
  context('template file', () => {
    it('should exist', () => should.exist(template));

    context('has expected properties', () => {
      it('should have property $schema', () => should.exist(template.$schema));
      it('should have property contentVersion', () => should.exist(template.contentVersion));
      it('should have property parameters', () => should.exist(template.parameters));
      it('should have property variables', () => should.exist(template.variables));
      it('should have property resources', () => should.exist(template.resources));
      it('should have property outputs', () => should.exist(template.outputs));
    });

    context('defines the expected parameters', () => {
      const actual = Object.keys(template.parameters);

      it('should have 11 parameters', () => actual.length.should.be.exactly(11));
      it('should have a prefix', () => actual.should.containEql('prefix'));
      it('should have a vnetPrefix', () => actual.should.containEql('vnetPrefix'));
      it('should have a subnet1Prefix', () => actual.should.containEql('subnet1Prefix'));
      it('should have a subnet2Prefix', () => actual.should.containEql('subnet2Prefix'));
      it('should have a agentCount', () => actual.should.containEql('agentCount'));
      it('should have a agentVMSize', () => actual.should.containEql('agentVMSize'));
      it('should have a linuxAdminUsername', () => actual.should.containEql('linuxAdminUsername'));
      it('should have a sshRSAPublicKey', () => actual.should.containEql('sshRSAPublicKey'));
      it('should have a servicePrincipalClientId', () => actual.should.containEql('servicePrincipalClientId'));
      it('should have a servicePrincipalClientSecret', () => actual.should.containEql('servicePrincipalClientSecret'));
      it('should have a kubernetesVersion', () => actual.should.containEql('kubernetesVersion'));
    });

    context('creates the expected resources', () => {
      const actual = template.resources.map(resource => resource.type);
      const securityGroups = actual.filter(resource => resource === 'Microsoft.Network/networkSecurityGroups');

      it('should have 3 resources', () => actual.length.should.be.exactly(5));
      it('should create Microsoft.Network/virtualNetworks', () => actual.should.containEql('Microsoft.Network/virtualNetworks'));
      it('should create 2 Microsoft.Network/networkSecurityGroups', () => securityGroups.length.should.be.exactly(2));
      it('should create Microsoft.ContainerRegistry/registries', () => actual.should.containEql('Microsoft.ContainerRegistry/registries'));
      it('should create Microsoft.ContainerService/managedClusters', () => actual.should.containEql('Microsoft.ContainerService/managedClusters'));
    });

    context('vnet has expected properties', () => {
      const network = template.resources.find(resource => resource.type === 'Microsoft.Network/virtualNetworks');

      it('should define addressSpace', () => should.exist(network.properties.addressSpace));
      it('should define 2 subnets', () => network.properties.subnets.length.should.be.exactly(2));
    });

    context('each subnet has a defined network security group assigned', () => {
      const network = template.resources.find(resource => resource.type === 'Microsoft.Network/virtualNetworks');
      const subnetProps = network.properties.subnets.map(subnet => subnet.properties).sort();
      subnetProps.forEach(property => {
        it('should define a network security group', () => should.exist(property.networkSecurityGroup));
      });
    });

    context('has expected output', () => {
      it('should define virtualNetwork', () => should.exist(template.outputs.virtualNetwork));
      it('should define virtualNetwork id', () => should.exist(template.outputs.virtualNetwork.value.id));
      it('should define virtualNetwork name', () => should.exist(template.outputs.virtualNetwork.value.name));

      it('should define subnets', () => should.exist(template.outputs.subnets));
      it('should define subnet1 id', () => should.exist(template.outputs.subnets.value.subnet1Id));
      it('should define subnet2 id', () => should.exist(template.outputs.subnets.value.subnet2Id));
      
      it('should define securityGroup', () => should.exist(template.outputs.securityGroups));
      it('should define nsg1 id', () => should.exist(template.outputs.securityGroups.value.nsg1Id));
      it('should define nsg2 id', () => should.exist(template.outputs.securityGroups.value.nsg2Id));

      it('should define containerRegistry', () => should.exist(template.outputs.containerRegistry));
      it('should define registry id', () => should.exist(template.outputs.containerRegistry.value.id));
      it('should define registry name', () => should.exist(template.outputs.containerRegistry.value.name));

      it('should define controlPlane', () => should.exist(template.outputs.controlPlane));
      it('should define controlPlan FQDN', () => should.exist(template.outputs.controlPlane.value.fqdn));
    });
  });

  context('parameters file', (done) => {
    it('should exist', () => should.exist(parameters));

    context('has expected properties', () => {
      it('should define $schema', () => should.exist(parameters.$schema));
      it('should define contentVersion', () => should.exist(parameters.contentVersion));
      it('should define parameters', () => should.exist(parameters.parameters));
    });
  });
});
