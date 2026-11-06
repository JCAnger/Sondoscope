# Sondoscope

App SwiftUI multiplateforme (iPhone, iPad, Mac natif, widget) : moyenne pondérée des sondages de la présidentielle française de 2027. Langue de l'interface : français.

## Règles
- Neutralité stricte : aucun classement de fond, aucune recommandation de vote, pas de couleurs de partis, pas de photos.
- Ne jamais inventer de donnée. Les données fictives restent limitées au Debug et aux tests, avec un bandeau.
- Silence électoral : rien n'est affiché ni publié pendant les périodes de `ElectoralSilence`.
- Chaque sondage affiche institut, commanditaire, dates, échantillon et lien vers la notice.
- Style : Aqua modernisé, pastel bleu et vert, animations douces, respect de « Réduire les animations ».

## Structure
- `Shared/` : domaine, moteur (`AverageEngine`), données, design system. Compilé dans l'app, le widget et les tests.
- `Sondoscope/` : app. `SondoscopeWidget/` : widget. `SondoscopeTests/` : tests Swift Testing.
- `pipeline/build_polls.py` : importe les JSON 2027etmoi vers `polls.json`. Tests : `python3 -m unittest discover -s pipeline/tests`.
- `.github/workflows/update-polls.yml` : publication quotidienne sur https://jcanger.github.io/Sondoscope/polls.json. Ne pas supprimer `pipeline/archive/`, c'est le seul historique complet.

## Points ouverts
- Fiche sondage : ouverture lente signalée sur ceux qui ont beaucoup d'hypothèses. Allègement livré (matériau au lieu de Liquid Glass, LazyVStack, cache de la moyenne), à confirmer.
- Décider si les sondages commandés par un candidat sortent des moyennes.
- Catalogue de traductions à remplir ; textes légaux à faire relire.
