'use strict';
'require view';
'require dom';
'require poll';
'require uci';
'require rpc';
'require fs';

var callMwan3nftStatus = rpc.declare({
	object: 'luci.mwan3nft',
	method: 'status',
	expect: { }
});

var callInitAction = rpc.declare({
	object: 'luci',
	method: 'setInitAction',
	params: [ 'name', 'action' ],
	expect: { result: false }
});

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('mwan3nft'),
			L.resolveDefault(fs.exec('/usr/sbin/mwan3nft', ['status']), { stdout: '' })
		]);
	},

	pollStatus: function() {
		return L.resolveDefault(fs.exec('/usr/sbin/mwan3nft', ['status']), { stdout: '' }).then(function(res) {
			var statusDiv = document.getElementById('mwan3nft-status');
			if (statusDiv && res.stdout) {
				statusDiv.innerHTML = '<pre>' + res.stdout + '</pre>';
			}
		});
	},

	render: function(data) {
		var m, s, o;
		var statusOutput = data[1] ? data[1].stdout : '';

		var view = E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('MultiWAN NFT Manager')),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Service Control')),
				E('div', { 'class': 'cbi-value' }, [
					E('button', {
						'class': 'btn cbi-button cbi-button-apply',
						'click': L.bind(function() {
							return callInitAction('mwan3nft', 'start').then(function() {
								window.location.reload();
							});
						}, this)
					}, _('Start')),
					' ',
					E('button', {
						'class': 'btn cbi-button cbi-button-reset',
						'click': L.bind(function() {
							return callInitAction('mwan3nft', 'stop').then(function() {
								window.location.reload();
							});
						}, this)
					}, _('Stop')),
					' ',
					E('button', {
						'class': 'btn cbi-button cbi-button-action',
						'click': L.bind(function() {
							return callInitAction('mwan3nft', 'restart').then(function() {
								window.location.reload();
							});
						}, this)
					}, _('Restart')),
					' ',
					E('button', {
						'class': 'btn cbi-button cbi-button-action',
						'click': L.bind(function() {
							return callInitAction('mwan3nft', 'reload').then(function() {
								window.location.reload();
							});
						}, this)
					}, _('Reload'))
				])
			]),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Interface Status')),
				E('div', { 'id': 'mwan3nft-status', 'class': 'cbi-value' }, [
					E('pre', {}, statusOutput || _('Loading...'))
				])
			]),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Quick Info')),
				E('table', { 'class': 'table' }, [
					E('tr', { 'class': 'tr' }, [
						E('td', { 'class': 'td' }, _('Enabled')),
						E('td', { 'class': 'td' }, uci.get('mwan3nft', 'globals', 'enabled') == '1' ? _('Yes') : _('No'))
					]),
					E('tr', { 'class': 'tr' }, [
						E('td', { 'class': 'td' }, _('Firewall Mark Mask')),
						E('td', { 'class': 'td' }, uci.get('mwan3nft', 'globals', 'mmx_mask') || '0x3F00')
					]),
					E('tr', { 'class': 'tr' }, [
						E('td', { 'class': 'td' }, _('Local Source')),
						E('td', { 'class': 'td' }, uci.get('mwan3nft', 'globals', 'local_source') || 'lan')
					])
				])
			]),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('About')),
				E('p', {}, _('mwan3nft is a multi-WAN load balancing and failover manager using nftables.')),
				E('p', {}, _('It is compatible with OpenClash, Lucky and other applications that use their own firewall marks.')),
				E('ul', {}, [
					E('li', {}, _('Load balancing with weighted distribution')),
					E('li', {}, _('Failover with health checking')),
					E('li', {}, _('Policy-based routing')),
					E('li', {}, _('Sticky sessions support')),
					E('li', {}, _('IPv4 and IPv6 support'))
				])
			])
		]);

		poll.add(L.bind(this.pollStatus, this), 5);

		return view;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
