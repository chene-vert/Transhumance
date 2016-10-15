#!/bin/bash 

# Sera la date de l'archive
LADATE=$(date '+%Y-%m-%d-%H-%M-%S')

# Construit la liste des sites web possible à sauvgarder
# c-a-d un repertoire contenant un fichier settings.conf
LIST_SITE=( $(find "$(readlink -f ${0%/*})" -mindepth 2 -maxdepth 2 -type f -name "settings.conf" | sort  | sed 's@/settings.conf$@@' )  )

# Propose à l'utilisateur la liste des sites
((i=0))
printf "\nLISTE DES SITES:\n\n" 
for b in "${LIST_SITE[@]}"
do
  [ -d "${b}" ] && printf "${i}) ${b##*/}\n"
  ((i++))
done
printf "\n" 

# Demande à l'utilisateur de selectionner le site à sauvgarder
read -p "Selectionner le site à sauvegarder [0] : " idx_sel
ROOT_DIR="${LIST_SITE[$idx_sel]}"
BACKUP_PATH="${ROOT_DIR}/${LADATE}"

# Recupère users et mots de passes
DB_USER=${ROOT_DIR##*/}
FTP_USER=${DB_USER%.free.fr}
DB_USER=${FTP_USER}

. "${ROOT_DIR}/settings.conf" 

# Demande la confirmation / possibilité d'annuler
printf "\nLe site qui va être sauvegardé est : ${ROOT_DIR##*/} [OK:enter ou CTRL+C]\n\n"
read a

# Création du répertoire de sauvegarde
mkdir -p "${BACKUP_PATH}" 
cd "${BACKUP_PATH}"

# Création du  repertoire log
[ -d  "log" ] || mkdir log

# Backup complet : database sql et fichiers
# Affiche user et mot de passe ( permet à l'utilisateur de vérifier ) 
printf "DB_USER=${DB_USER}   : DB_PASSWD=${DB_PASSWD}\n"
printf "FTP_USER=${FTP_USER} : FTP_PASSWD=${FTP_PASSWD}\n\n"

# Construit le nom de la base de donnée à partir du nom du site
DB=$( printf ${ROOT_DIR##*/} | tr -s "." "_" )

# Logging et récupere le token
# debug : --trace-ascii trace.txt
curl --user "${DB_USER}:${DB_PASSWD}" --cookie-jar "log/backup_cookie.txt" \
     --user-agent "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)" \
     --referer "http://sql.free.fr" --header "Accept-Encoding: gzip, deflate" \
     "http://phpmyadmin.free.fr/phpMyAdmin/" -o "log/backup_responseA.txt"


TOKEN=$( cat log/backup_responseA.txt | grep "var *token *= *" | cut -d\' -f2)
printf  "\nTOKEN=${TOKEN}\n\n"

# Interroge pour recuperer la structure de la base : le nom des tables 
# debug : --trace-ascii trace.txt 
curl --user "${DB_USER}:${DB_PASSWD}" --cookie "log/backup_cookie.txt" \
     --user-agent "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)" \
     --referer "http://sql.free.fr"  \
     "http://phpmyadmin.free.fr/phpMyAdmin/db_structure.php?token=${TOKEN}&db=${DB}" -o "log/backup_responseB.txt"

# Extrait le tableau des tables SQL depuis la reponse 
TABLES=(  $( sed -n '/id="tablesForm"/,/Exécuter/{/<th><label for/,/\/label>/{/title/s/.*title="\(.*\)".*/\1/p}}' "log/backup_responseB.txt" )  )

# LISTE des tables a sauvgarder
for t in "${TABLES[@]}"
do
TABLE_SELECT+="table_select%5B%5D=${t}&"
done

POST="db=${DB}&token=${TOKEN}&export_type=database&${TABLE_SELECT}\
what=sql&codegen_data=&codegen_format=0&csv_separator=%3B&\
csv_enclosed=%22&csv_escaped=%5C&csv_terminated=AUTO&csv_null=NULL&\
csv_data=&excel_null=NULL&excel_edition=win&excel_data=&htmlexcel_null=NULL&\
htmlexcel_data=&htmlword_structure=something&htmlword_data=something&htmlword_null=NULL&\
latex_caption=something&latex_structure=something&latex_structure_caption=Structure+de+la+table+__TABLE__&\
latex_structure_continued_caption=Structure+de+la+table+__TABLE__+%28suite%29&\
latex_structure_label=tab%3A__TABLE__-structure&latex_comments=something&latex_data=something&\
latex_columns=something&latex_data_caption=Contenu+de+la+table+__TABLE__&\
latex_data_continued_caption=Contenu+de+la+table+__TABLE__+%28suite%29&latex_data_label=tab%3A__TABLE__-data&\
latex_null=%5Ctextit%7BNULL%7D&ods_null=NULL&ods_data=&odt_structure=something&odt_comments=something&\
odt_data=something&odt_columns=something&odt_null=NULL&pdf_report_title=&pdf_data=1&sql_header_comment=&\
sql_include_comments=something&sql_compatibility=NONE&sql_structure=something&sql_drop_table=something&\
sql_if_not_exists=something&sql_auto_increment=something&sql_backquotes=something&sql_procedure_function=something&\
sql_data=something&sql_columns=something&sql_extended=something&sql_max_query_size=50000&sql_hex_for_blob=something&\
sql_type=INSERT&texytext_structure=something&texytext_data=something&texytext_null=NULL&xml_data=&yaml_data=&\
asfile=sendit&filename_template=__DB__&remember_template=on&charset_of_file=utf-8&compression=zip"

# Sauvegarde la base de donnée
curl --user "${DB_USER}:${DB_PASSWD}" --cookie "log/backup_cookie.txt" \
     --user-agent "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)" \
     --referer "http://phpmyadmin.free.fr/phpMyAdmin/" --header "Accept-Encoding: gzip, deflate" \
     --data "$POST" "http://phpmyadmin.free.fr/phpMyAdmin/export.php" -o "database.zip"

# Demande à l'utlisateur s'il veut également sauvgarder les fichiers
# Souvant assez long car pas de transfert // chez FREE
printf "\nTous les fichiers vont être sauvegarder [OK:enter ou CTRL+C]\n\n"
read a

lftp   <<!!!!
lcd "${BACKUP_PATH}"
debug 3 -o "log/backup_lftp.log"
set mirror:parallel-transfer-count 1
set mirror:set-permissions false
open ftp://ftpperso.free.fr
user ${FTP_USER} ${FTP_PASSWD}
mirror / site
exit
!!!!

# Tar gz du site (prend moins de place et évite les modifications par inadvertance )
if [ -d site ]
then
	zip -r site.zip site
    rm -rf site
fi
