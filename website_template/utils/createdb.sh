#!/bin/bash

createuser -AD -U postgres $SYSTEM
dropdb -U postgres $SYSTEM
createdb -E koi8-r -U postgres -O $SYSTEM $SYSTEM
psql -U $SYSTEM < ./doc/database.sql
