'use strict';
'require view';
'require dom';
'require poll';
'require uci';
'require rpc';
'require fs';

var callInitAction = rpc.declare({
	object: 'luci',
	method: 'setInitAction',
	params: [ 'name', 'action' ],
	expect: { result: false }
});

return view.extend({
	load: function() {
		return uci.load('mwan3nft').then(function() {
			return L.resolveDefault(fs.exec('/usr/sbin/mwan3nft', ['status']), { code: 1, stdout: '', stderr: '' });
		}).catch(function() {
			return { code: 1, stdout: '', stderr: '' };
		});
	},

	pollStatus: function() {
		return L.resolveDefault(fs.exec('/usr/sbin/mwan3nft', ['status']), { code: 1, stdout: '', stderr: '' }).then(function(res) {
			var statusDiv = document.getElementById('mwan3nft-status');
			if (statusDiv) {
				if (res && res.stdout && res.stdout.length > 0) {
					statusDiv.innerHTML = '<pre>' + res.stdout + '</pre>';
				} else {
					statusDiv.innerHTML = '<em>' + _('Service is not running or mwan3nft command not found.') + '</em>';
				}
			}
		}).catch(function() {
			var statusDiv = document.getElementById('mwan3nft-status');
			if (statusDiv) {
				statusDiv.innerHTML = '<em>' + _('Unable to get status.') + '</em>';
			}
		});
	},

	render: function(statusResult) {
		var statusOutput = '';
		if (statusResult && statusResult.stdout) {
			statusOutput = statusResult.stdout;
		}

		var enabled = uci.get('mwan3nft', 'globals', 'enabled');
		var mmxMask = uci.get('mwan3nft', 'globals', 'mmx_mask');
		var localSource = uci.get('mwan3nft', 'globals', 'local_source');

		var view = E('div', { 'class': 'cbi-map' }, [
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
				E('div', { 'id': 'mwan3nft-status', 'class': 'cbi-value' },
					statusOutput
						? E('pre', {}, statusOutput)
						: E('em', {}, _('Service is not running or mwan3nft command not found.'))
				)
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

		poll.add(L.bind(this.pollStatus, this), 10);

		return view;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
