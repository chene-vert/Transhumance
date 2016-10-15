#!/bin/bash


# Construit la liste des sites web possible à sauvgarder
# c-a-d un repertoire contenant un fichier settings.conf
LIST_SITE=( $(find "$(readlink -f ${0%/*})" -mindepth 1 -maxdepth 1 -type d | sort | sed 's@/settings.conf$@@' )  )

# Propose à l'utilisateur la liste des sites
((i=0))
printf "\nLISTE DES SITES:\n\n" 
for b in "${LIST_SITE[@]}"
do
  printf "${i}) ${b##*/}\n"
  ((i++))
done
printf "\n" 

# Demande à l'utilisateur de selectionner le site à sauvgarder
read -p "Selectionner le site à sauvegarder [0] : " idx_site

# Selection du site a restorer
ROOT_DIR="${LIST_SITE[$idx_site]}"

# Recupère users et mots de passes
DB_USER=${ROOT_DIR##*/}
FTP_USER=${DB_USER%.free.fr}
DB_USER=${FTP_USER}
. "${ROOT_DIR}/settings.conf" 

printf "\nLe site qui va être restauré est : ${ROOT_DIR##*/}\n\n"

# Construit la liste des backup pour le site selectionné
LIST_BACKUP=( $(find "${ROOT_DIR}" -mindepth 1 -maxdepth 1 -name "20*" -type d | sort -r )  )

# Propose à l'utilisateur la liste des backup possibles
((i=0))
for b in "${LIST_BACKUP[@]}"
do
  LA_DATE=( $(echo ${b##*/} | tr -s "-" " ") )
  LA_DATE="${LA_DATE[2]}/${LA_DATE[1]}/${LA_DATE[0]} ${LA_DATE[3]}:${LA_DATE[4]}:${LA_DATE[5]}"
  echo "${i}) ${LA_DATE}"
  ((i++))
done
printf "\n" 

read -p "Selectionner le n° du backup à restaurer  [0] : " idx_backup 


# La date choisie
BACKUP_PATH="${LIST_BACKUP[$idx_backup]}"
LA_DATE=( $(echo ${BACKUP_PATH##*/} | tr -s "-" " ") )
LA_DATE="${LA_DATE[2]}/${LA_DATE[1]}/${LA_DATE[0]} ${LA_DATE[3]}:${LA_DATE[4]}:${LA_DATE[5]}"

# Backup complet : database sql et fichiers
cd "${BACKUP_PATH}"

printf "\nATTENTION : ${ROOT_DIR##*/} va être restauré à la date du ${LA_DATE} [OK:enter ou CTRL+C]\n\n"
read a


# creation du  repertoire log
[ -d  "log" ] || mkdir log

> "log/restore_cookie.txt"
> "log/restore_trace.txt"
> "log/restore_responseA.txt"
> "log/restore_responseB.txt"

# Database name
DB=$( printf ${ROOT_DIR##*/} | tr -s "." "_" )

# Backup complet : database sql et fichiers
printf "DB_USER=${DB_USER}   : DB_PASSWD=${DB_PASSWD}\n"
printf "FTP_USER=${FTP_USER} : FTP_PASSWD=${FTP_PASSWD}\n"

printf "\nDATABASE_NAME=${DB%_free_fr}\n\n"

curl --trace-ascii trace.txt --user "${DB_USER}:${DB_PASSWD}" --cookie-jar "log/restore_cookie.txt"  \
              --user-agent "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)"  "http://phpmyadmin.free.fr/phpMyAdmin/" \
              -o "log/restore_responseA.txt"

TOKEN=$( cat log/restore_responseA.txt | grep "var token = " | cut -d\' -f2)

printf  "\nTOKEN=${TOKEN}\n\n"

[ -z "${TOKEN}" ] && { printf "Bad login, exit" ; exit ; }

curl --trace-ascii trace.txt --user "${DB_USER}:${DB_PASSWD}" --cookie "log/restore_cookie.txt"   \
     --user-agent "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)" \
     --referer "http://phpmyadmin.free.fr/phpMyAdmin" --header "Accept-Encoding: gzip, deflate" \
     --form "db=${DB%_free_fr}" --form "token=${TOKEN}" --form "format=sql" \
     --form 'import_type=database' --form "import_file=@database.zip;type=application/zip"  \
     "http://phpmyadmin.free.fr/phpMyAdmin/import.php" -o "log/restore_responseB.txt"


if [ -f "site.zip" ]
then

printf "\nTous les fichiers distants vont être supprimés et les fichiers seront restaurés à la date du ${BACKUP_PATH##*/} [OK:enter ou CTRL+C]\n\n"
read a

unzip site.zip

lftp <<!!!!
debug 3 -o "log/restore_lftp.log"
lcd "${BACKUP_PATH}/site"
set mirror:parallel-transfer-count 1
set mirror:set-permissions false
open ftp://ftpperso.free.fr
user ${FTP_USER} ${FTP_PASSWD}
mirror -R --delete-first 
bye
!!!!

rm -rf site

fi
