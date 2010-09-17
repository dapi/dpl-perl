#!/bin/sh

SYSTEM=$1
DATABASE=$2 # || $SYSTEM
SITE=$3 # || $SYSTEM
echo "$SYSTEM $DATABSE $SITE"

if [ ! "$SYSTEM" -o ! "$DATABASE" -o ! "$SITE" ]; then
 echo "Не указана система. Запускать website_template/utils/make_website.sh SYSTEM DATABASE SITE"
 exit
fi

cp -vr website_template $SYSTEM
cd $SYSTEM
mv SYSTEM $SYSTEM

touch ./utils/.update_time

find . -type f | xargs perl -i -p -e "s/\\\$SYSTEM/$SYSTEM/g"
find . -type f | xargs perl -i -p -e "s/\\\$DATABASE/$DATABASE/g"
find . -type f | xargs perl -i -p -e "s/\\\$SITE/$SITE/g"

echo
echo "******************************"
echo
echo -e "Добавить в startup.pl:\n\n\tuse lib qw(/home/danil/projects/$SYSTEM/);\n\tuse $SYSTEM::define;"

echo "
в httpd.conf:

 <Location /projects/$SYSTEM/>
    SetHandler perl-script
    PerlSetVar subsystem $SYSTEM
    PerlResponseHandler  dpl::Web::Handler::SiteSelector->handler
 </Location>

"

echo "******************************"
