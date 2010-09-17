#!/bin/sh
server=$1
echo "Update dpl, el to $1"

cd /home/danil/projects/

utf="./dpl/.update_time_$server"
utf2="./dpl/.update_time2_$server"


dirs="dpl/ el/"
#dirs="dpl/ orionet/"
touch $utf2
if [ -f $utf ]; then
  files=`find $dirs -newer $utf -type f | grep -v svn | grep -v \~ | grep -v db\.xml | grep -v "log/" | grep -v bz2 | grep -v "tmp/" | grep -v gz  | grep -v "var/" | grep -v CVS | grep -v log/ | grep -v images/ | grep -vi .bak$ | grep -vi .db$ | grep -v BAK | grep -v "openbill/etc/local.xml" | grep -v \.# | grep -v \.update_time.* | grep -v "/\."`
else
  files=`find $dirs -type f | grep -v .svn | grep -v \~ | grep -v db\.xml | grep -v "log/" | grep -v bz2 | grep -v "tmp/" | grep -v gz  | grep -v "var/" | grep -v CVS | grep -v log/ | grep -v images/ | grep -vi .bak$ | grep -vi .db$ | grep -v BAK | grep -v "openbill/etc/local.xml" | grep -v \.# | grep -v \.update_time.* | grep -v "/\."`
  scp -r /home/danil/projects/dpl/ danil@orionet.ru:/home/danil/projects/
#  ssh danil@orionet.ru:/home/danil/projects/orionet/utils/receiveupdate.sh 2
  mv $utf2 $utf
fi
if [ "$files" ]; then
  echo "Files to copy:"
  restart=0
  if echo "$files" | grep ".pm\|system.xml"  >/dev/null; then
     if [ "$1" != "1" ]; then
        echo "Restart"
        restart=1
     fi
  fi
  list=`echo "$files" | xargs`

  (tar cvf - $list | bzip2 -c | ssh danil@$server /home/danil/projects/dpl/receiveupdate.sh $restart) && mv $utf2 $utf
else
   echo "No new files.."
fi

exit $restart