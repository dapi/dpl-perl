#!/bin/sh
echo "Update $SYSTEM"

cd /home/danil/projects

utf="$SYSTEM/utils/.update_time"
utf2="$SYSTEM/utils/.update_time2"

dirs="dpl/ $SYSTEM/"
#dirs="dpl/ orionet/"

touch $utf2
if [ -f $utf ]; then
  files=`find $dirs -newer $utf -type f | grep -v \~ | grep -v db\.xml | grep -v "log/" | grep -v bz2 | grep -v "tmp/" | grep -v gz  | grep -v "var/" | grep -v CVS | grep -v log/ | grep -v images/ | grep -vi .bak$ | grep -vi .db$ | grep -v BAK | grep -v "openbill/etc/local.xml" | grep -v \.# | grep -v \.update_time.* | grep -v "/\."`
else
  files=`find $dirs -type f | grep -v \~ | grep -v db\.xml | grep -v "log/" | grep -v bz2 | grep -v "tmp/" | grep -v gz  | grep -v "var/" | grep -v CVS | grep -v log/ | grep -v images/ | grep -vi .bak$ | grep -vi .db$ | grep -v BAK | grep -v "openbill/etc/local.xml" | grep -v \.# | grep -v \.update_time.* | grep -v "/\."`
  scp -r /home/danil/projects/$SYSTEM/ danil@orionet.ru:/home/danil/projects/
#  ssh danil@orionet.ru:/home/danil/projects/orionet/utils/receiveupdate.sh 2
  mv $utf2 $utf
  exit
fi

if [ "$files" ]; then
  echo "Files to copy:"
  restart=0
  if echo "$files" | grep .pm  >/dev/null; then
     if [ "$1" != "1" ]; then
        echo "Restart"
        restart=1
     fi
  fi
  list=`echo "$files" | xargs`
  (tar cvf - $list | bzip2 -c | ssh danil@orionet.ru /home/danil/projects/$SYSTEM/utils/receiveupdate.sh $restart) && mv $utf2 $utf
else
   echo "No new files.."
fi
