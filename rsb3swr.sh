#!/bin/bash
#
# RSBAK3 is Copyright (C) 2003 LINBIT <http://www.linbit.com/>.
#
# Written by Clifford Wolf <clifford@clifford.at>.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. A copy of the GNU General Public
# License can be found at COPYING.

if [ -z "$SSH_ORIGINAL_COMMAND" ]; then
	echo
	echo "Helper app for setting up secure rsbak3 nodes using ssh."
	echo
	echo "This should be started from sshd based on a command=.. option"
	echo "in a ~/.ssh/authorized_keys2 file. See rsbak3(8) for details."
	echo
	exit 1
fi

# A sane rsync call for _reading_ should look like this:
#
# rsync --server --sender -r . /tmp/
#
# The exact option list can be very different, but the rsync call will
# always start with "rsync --server --sender".

if echo "$SSH_ORIGINAL_COMMAND" | \
   egrep -v '^rsync --server --sender [a-zA-Z0-9/\._ -]*$'
then
	logger -p authpriv.warn -t rsb3swr \
		"Deny starting rsync. Command doesn't match regex:" \
		"$SSH_ORIGINAL_COMMAND"
	exit 1
fi

exec $SSH_ORIGINAL_COMMAND

