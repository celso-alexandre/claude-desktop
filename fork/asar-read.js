#!/usr/bin/env node
// Stand-in for `asar extract-file <archive> <file>` when no app.asar patch is active
// (CLAUDE_OFFICIAL_ASAR=1): the build then only reads package.json, so it needs no
// npm package. Writes <file>'s basename into the current directory, like asar does.
//
// Layout: UInt32LE 4 | UInt32LE header-pickle size | pickle(UInt32LE payload size,
// UInt32LE JSON length, JSON header); file offsets are relative to 8 + header-pickle size.
'use strict';
const fs = require('fs');
const path = require('path');

const [cmd, archive, file] = process.argv.slice(2);
if (cmd === '--version') {
	console.log('fork/asar-read.js (extract-file only)');
	process.exit(0);
}
if (cmd !== 'extract-file' || !archive || !file) {
	console.error('usage: asar-read.js extract-file <archive> <file>');
	process.exit(2);
}

const fd = fs.openSync(archive, 'r');
const read = (pos, len) => {
	const buf = Buffer.alloc(len);
	fs.readSync(fd, buf, 0, len, pos);
	return buf;
};
const pickleSize = read(4, 4).readUInt32LE(0);
const jsonLength = read(12, 4).readUInt32LE(0);
const header = JSON.parse(read(16, jsonLength).toString('utf8'));

let node = header;
for (const part of file.split('/')) {
	node = node.files && node.files[part];
	if (!node) {
		console.error(`${file}: not in ${archive}`);
		process.exit(1);
	}
}
if (node.unpacked || node.offset === undefined) {
	console.error(`${file}: not a packed file in ${archive}`);
	process.exit(1);
}
const data = read(8 + pickleSize + Number(node.offset), node.size);
fs.writeFileSync(path.basename(file), data);
