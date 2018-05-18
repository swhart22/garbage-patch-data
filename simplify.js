const d3 = require('d3');
const fs = require('fs');
const _ = require('lodash');

fs.readFile('./intermediate/world.json', (error, world) => {
	let data = JSON.parse(world);

	data.features = data.features.filter(g => {
		let isCan = g['properties']['NAME'] == 'Canada',
		isUS = g['properties']['NAME'] == 'United States',
		isMexico = g['properties']['NAME'] == 'Mexico';

		return isUS | isCan | isMexico;
	});

	data = JSON.stringify(data);
	fs.writeFile('./intermediate/world-simplified.json', data, error => {
		if (error) console.log('error processing data');
	});
});