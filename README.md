# Transhumance : mettez vos pages perso à l'abri pour l'hiver ! 

Permet la sauvegarde et la restauration par script des Pages Perso du fournisseur d'accès internet FREE.FR

 - gère plusieurs sites
 - sauvegarde/restauration complete : Base de donnée MySQL et fichiers
 - compresse en zip
 
 *Note: Pourquoi le format zip ? Il permet de facilier le contrôle manuel de l'archive. 
 Sous windows on peut accéder au contenu d'un zip comme si c'était un répertoire*

**Note : Les deux scripts sont donnés comme tel sans garantie.** 

__FAITES UNE SAUVEGARDE MANUELLE DE LA BASE ET DES FICHIERS >> AVANT << !!!!__

# Prérequit

- cygwin avec
  * zip
  * unzip
  * lftp
  * curl

Disposer les deux scripts `backup.sh` et `restore.sh` dans un répertoire (ex: Backup) .
Creez un répertoire qui a le nom du site à sauvegarder/restaurer et à l'interieur 
ajouter un fichier 'settings.conf' qui contient les mots de passes.

Arborescence 

    Backup
     |--- bakup.sh
     |--- restore.sh
     |
     |--- www.monsupersite1.free.fr
     |     |--- settings.conf
     | 
     |--- www.monsupersite2.free.fr
     |     |--- settings.conf
     | 
     |--- www.monsupersite3.free.fr
     |     |--- settings.conf


Les fichiers settings.conf contiennent les mots de passes nécessaires pour chaque site comme ci-dessous

    DB_PASSWD="mot de passe database mysql"
    FTP_PASSWD="mot de passe du FTP"

*NOTE: les mots de passes sont tous identiques s'ils n'ont pas été changés, mais les deux variables DB_PASSWD,FTP_PASSWD doivent être renseignés*


# Utilisation

Les scripts posent des questions, il suffit d'y répondre ...

## Sauvegarde 

`./backup.sh`


## Restauration

`./restore.sh`


