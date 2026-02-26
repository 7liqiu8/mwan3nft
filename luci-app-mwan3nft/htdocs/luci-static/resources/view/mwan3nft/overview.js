'use strict';
'require view';
'require dom';
'require poll';
'require uci';
'require rpc';
'require fs';
'require network';

var callInitAction = rpc.declare({
	object: 'luci',
	method: 'setInitAction',
	params: [ 'name', 'action' ],
	expect: { result: false }
});

function readIfaceStatus(iface) {
	return L.resolveDefault(fs.read('/var/run/mwan3nft/' + iface + '.status'), '').then(function(s) {
		return (s || '').trim() || 'unknown';
	});
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('mwan3nft'),
			network.getNetworks()
		]);
	},

	getIfaceStatusColor: function(status) {
		switch (status) {
			case 'online':  return '#4caf50';
			case 'offline': return '#f44336';
			default:        return '#9e9e9e';
		}
	},

	getIfaceStatusText: function(status) {
		switch (status) {
			case 'online':  return _('Online');
			case 'offline': return _('Offline');
			default:        return _('Unknown');
		}
	},

	renderInterfaceTable: function(networks) {
		var self = this;
		var ifaces = [];

		uci.sections('mwan3nft', 'interface', function(s) {
			ifaces.push(s['.name']);
		});

		var tableDiv = E('div', { 'id': 'mwan3nft-iface-table' });

		if (ifaces.length === 0) {
			tableDiv.appendChild(E('em', {}, _('No interfaces configured.')));
			return tableDiv;
		}

		var table = E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, _('Interface')),
				E('th', { 'class': 'th' }, _('Status')),
				E('th', { 'class': 'th' }, _('Enabled')),
				E('th', { 'class': 'th' }, _('Device')),
				E('th', { 'class': 'th' }, _('IP Address')),
				E('th', { 'class': 'th' }, _('Gateway')),
				E('th', { 'class': 'th' }, _('Tracking Method'))
			])
		]);

		var statusPromises = ifaces.map(function(iface) {
			return readIfaceStatus(iface).then(function(status) {
				var enabled = uci.get('mwan3nft', iface, 'enabled') || '0';
				var trackMethod = uci.get('mwan3nft', iface, 'track_method') || 'ping';
				var device = '-', ipaddr = '-', gateway = '-';

				for (var i = 0; i < networks.length; i++) {
					if (networks[i].getName() === iface) {
						var dev = networks[i].getDevice();
						device = dev ? dev.getName() : '-';
						var addrs = networks[i].getIPAddrs();
						ipaddr = (addrs && addrs.length > 0) ? addrs[0].split('/')[0] : '-';
						gateway = networks[i].getGatewayAddr() || '-';
						break;
					}
				}

				var statusColor = self.getIfaceStatusColor(status);
				var statusText = self.getIfaceStatusText(status);

				var row = E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td', 'style': 'font-weight:bold' }, iface),
					E('td', { 'class': 'td' }, [
						E('span', {
							'style': 'display:inline-block;width:12px;height:12px;border-radius:50%;background:' + statusColor + ';margin-right:6px;vertical-align:middle'
						}),
						E('span', { 'style': 'color:' + statusColor + ';font-weight:bold' }, statusText)
					]),
					E('td', { 'class': 'td' }, enabled === '1' ? _('Yes') : _('No')),
					E('td', { 'class': 'td' }, device),
					E('td', { 'class': 'td' }, ipaddr),
					E('td', { 'class': 'td' }, gateway),
					E('td', { 'class': 'td' }, trackMethod)
				]);

				table.appendChild(row);
			});
		});

		return Promise.all(statusPromises).then(function() {
			tableDiv.appendChild(table);
			return tableDiv;
		});
	},

	pollInterfaceStatus: function() {
		var self = this;

		return network.getNetworks().then(function(networks) {
			return self.renderInterfaceTable(networks);
		}).then(function(tableDiv) {
			var container = document.getElementById('mwan3nft-iface-container');
			if (container) {
				dom.content(container, tableDiv);
			}
		}).catch(function() {});
	},

	render: function(data) {
		var self = this;
		var networks = data[1] || [];

		var enabled = uci.get('mwan3nft', 'globals', 'enabled');
		var mmxMask = uci.get('mwan3nft', 'globals', 'mmx_mask');
		var localSource = uci.get('mwan3nft', 'globals', 'local_source');

		var ifaceContainer = E('div', { 'id': 'mwan3nft-iface-container' }, [
			E('em', {}, _('Loading...'))
		]);

		var detailContainer = E('div', { 'id': 'mwan3nft-detail-status' }, [
			E('em', {}, _('Loading...'))
		]);

		var pageView = E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('MultiWAN NFT Manager')),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Service Control')),
				E('div', { 'class': 'cbi-value' }, [
					E('button', {
						'class': 'btn cbi-button cbi-button-apply',
						'click': function() {
							return callInitAction('mwan3nft', 'start').then(function() {
								window.location.reload();
							});
						}
					}, _('Start')),
					' ',
					E('button', {
						'class': 'btn cbi-button cbi-button-reset',
						'click': function() {
							return callInitAction('mwan3nft', 'stop').then(function() {
								window.location.reload();
							});
						}
					}, _('Stop')),
					' ',
					E('button', {
						'class': 'btn cbi-button cbi-button-action',
						'click': function() {
							return callInitAction('mwan3nft', 'restart').then(function() {
								window.location.reload();
							});
						}
					}, _('Restart')),
					' ',
					E('button', {
						'class': 'btn cbi-button cbi-button-action',
						'click': function() {
							return callInitAction('mwan3nft', 'reload').then(function() {
								window.location.reload();
							});
						}
					}, _('Reload'))
				])
			]),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Interface Status')),
				ifaceContainer
			]),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Quick Info')),
				E('table', { 'class': 'table' }, [
					E('tr', { 'class': 'tr' }, [
						E('td', { 'class': 'td' }, _('Enabled')),
						E('td', { 'class': 'td' }, enabled == '1' ? _('Yes') : (enabled == '0' ? _('No') : _('N/A')))
					]),
					E('tr', { 'class': 'tr' }, [
						E('td', { 'class': 'td' }, _('Firewall Mark Mask')),
						E('td', { 'class': 'td' }, mmxMask || _('N/A'))
					]),
					E('tr', { 'class': 'tr' }, [
						E('td', { 'class': 'td' }, _('Local Source')),
						E('td', { 'class': 'td' }, localSource || _('N/A'))
					])
				])
			]),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Detailed Status')),
				detailContainer
			])
		]);

		// Load interface table
		self.renderInterfaceTable(networks).then(function(tableDiv) {
			dom.content(ifaceContainer, tableDiv);
		});

		// Load detailed status
		L.resolveDefault(fs.exec('/usr/sbin/mwan3nft', ['status']), { code: 1, stdout: '', stderr: '' }).then(function(res) {
			if (res && res.stdout && res.stdout.length > 0) {
				dom.content(detailContainer, E('pre', { 'style': 'font-size:12px;overflow-x:auto' }, res.stdout));
			} else {
				dom.content(detailContainer, E('em', {}, _('Service is not running.')));
			}
		}).catch(function() {
			dom.content(detailContainer, E('em', {}, _('Unable to get status.')));
		});

		// Poll interface status every 10 seconds
		poll.add(L.bind(this.pollInterfaceStatus, this), 10);

		return pageView;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
