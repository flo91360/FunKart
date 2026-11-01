"""Vérifie l'exécutable Windows exporté : numéro de version et icône.

    python3 .github/scripts/verifier_exe.py <FunKart.exe> <modèle Godot .exe> <version>

- la version du fichier et du produit (propriétés de l'exe dans Windows)
  doit être celle du jeu (config/version de project.godot) ;
- l'icône doit être celle du jeu, pas celle de Godot (comparée à l'icône du
  modèle d'export, d'où vient l'exe).
"""
import sys

import pefile


def icones(chemin):
    pe = pefile.PE(chemin)
    out = []
    if not hasattr(pe, "DIRECTORY_ENTRY_RESOURCE"):
        return pe, out
    for entree in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if entree.id != pefile.RESOURCE_TYPE["RT_ICON"]:
            continue
        for i in entree.directory.entries:
            for langue in i.directory.entries:
                d = langue.data.struct
                out.append(pe.get_data(d.OffsetToData, d.Size))
    return pe, out


def version(info_ms, info_ls):
    return (info_ms >> 16, info_ms & 0xFFFF, info_ls >> 16, info_ls & 0xFFFF)


def main():
    exe, modele, attendue = sys.argv[1:4]
    parties = [int(x) for x in attendue.split(".")]
    attendue_t = tuple((parties + [0, 0, 0, 0])[:4])
    pe, icones_exe = icones(exe)
    _, icones_modele = icones(modele)
    erreurs = []
    info = pe.VS_FIXEDFILEINFO[0]
    fichier = version(info.FileVersionMS, info.FileVersionLS)
    produit = version(info.ProductVersionMS, info.ProductVersionLS)
    print("Version du fichier :", fichier, "- du produit :", produit, "- attendue :", attendue_t)
    if fichier != attendue_t or produit != attendue_t:
        erreurs.append("le numéro de version de l'exe n'est pas celui du jeu (%s)" % attendue)
    print("Icônes : %d dans l'exe, %d dans le modèle Godot" % (len(icones_exe), len(icones_modele)))
    if not icones_exe:
        erreurs.append("l'exe n'a pas d'icône")
    elif set(icones_exe) & set(icones_modele):
        erreurs.append("l'exe porte encore l'icône de Godot")
    for e in erreurs:
        print("::error::Exécutable Windows : " + e)
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
