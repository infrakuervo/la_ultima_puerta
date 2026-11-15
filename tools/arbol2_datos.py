#!/usr/bin/env python3
"""Migración de datos de «Árbol 2» (se ejecutó una vez; queda como referencia de cómo se generó).
Quita los ocho remates «+X%» y añade piedras angulares, parejas excluyentes, nodos de dones
y las dos ramas que se ganan. Uso: python3 tools/arbol2_datos.py"""
import json, os
P = os.path.join(os.path.dirname(__file__), "..", "data", "skills.json")
d = json.load(open(P, encoding="utf-8"))
if any(n.get("keystone") for n in d["nodes"]):
    raise SystemExit("ya aplicado")

REMATES = ["brasa_maestria", "rayo_tormenta", "eco_sabueso", "beast_furia", "sab_alfa", "horno_infierno", "trueno_tormenta", "ojo_mirada"]
d["legacy"] = {n["id"]: {"cost_base": n["cost_base"], "cost_step": n["cost_step"], "max": n["max"]} for n in d["nodes"] if n["id"] in REMATES}
d["nodes"] = [n for n in d["nodes"] if n["id"] not in REMATES]
d["_doc"] = ("keystone: piedra angular (cambia una regla, con contrapartida). excl: id del nodo que queda vetado al comprar este. "
             "side: se dibuja en la columna lateral. branches[].unlock: asedio que hay que ganar para abrir la rama. "
             "legacy: nodos retirados (para devolver su esencia a las partidas guardadas). "
             "Claves especiales: set.need.<familia> (dones para la resonancia), set.power.<familia>, "
             "draft.family.<familia>, draft.kind.<bestia>, draft.rarity.<rareza>.")

d["branches"] += [
    {"id": "abismo", "name": "Abismo", "color": "7fe0a0", "route": "", "unlock": "alba", "unlock_text": "Gana el segundo asedio: la Orden del Alba"},
    {"id": "inquisicion", "name": "Inquisición", "color": "f2e2b0", "route": "", "unlock": "inquisicion", "unlock_text": "Gana el tercer asedio: la Inquisición"},
]

def R(*a):
    return [{"id": a[i], "rank": a[i + 1]} for i in range(0, len(a), 2)]

def F(**kw):
    out = []
    for k, v in kw.items():
        k = k.replace("__", ".")
        kind, val = v
        out.append({"k": k, kind: val})
    return out

def node(id, branch, name, desc, mx, row, fx, req, base, step, **extra):
    n = {"id": id, "branch": branch, "name": name, "desc": desc, "max": mx, "row": row, "fx": fx, "req": req, "cost_base": base, "cost_step": step}
    n.update(extra)
    d["nodes"].append(n)

def ks(id, branch, name, desc, fx, req, row=3):
    node(id, branch, name, desc, 1, row, fx, req, 80, 0, keystone=True, side=True)

def pair(a, b, req):
    for x, y in ((a, b), (b, a)):
        node(x[0], x[1], x[2], x[3], 2, 5, x[4], req, 45, 10, excl=y[0])

def boon(id, branch, name, desc, mx, row, fx, req):
    node(id, branch, name, desc, mx, row, fx, req, 35, 10, side=True, boon=True)

m, a = "mul", "add"
# --- Brasa
ks("brasa_tierra", "brasa", "Tierra quemada", "La Brasa deja el suelo ardiendo 5 s: quema a quien lo pise. A cambio tarda el doble en recargarse.",
   [{"k": "special.brasa_ground", a: 5.0}, {"k": "brasa.cd", m: 1.0}], R("brasa_dmg", 3))
boon("brasa_infierno", "brasa", "Corazón del Infierno", "La resonancia Infierno despierta con un solo don de fuego.", 1, 1,
     [{"k": "set.need.fuego", a: -1}], R("brasa_burn", 1))
pair(("brasa_cometa", "brasa", "Cometa", "Una Brasa enorme: +18% de daño y +8% de radio por rango.", [{"k": "brasa.dmg", m: 0.18}, {"k": "brasa.radius", m: 0.08}]),
     ("brasa_ascuas", "brasa", "Lluvia de ascuas", "Brasas pequeñas y seguidas: -10% de enfriamiento y -10% de retardo por rango.", [{"k": "brasa.cd", m: -0.10}, {"k": "brasa.delay", m: -0.10}]),
     R("brasa_echo", 1))
# --- Rayo
ks("rayo_arco", "rayo", "Arco voltaico", "El Rayo salta sin límite y sin bajar del 50% de su daño, pero solo salta a enemigos que arden.",
   [{"k": "special.rayo_arc", a: 1}], R("rayo_dmg", 3))
boon("rayo_heraldo", "rayo", "Heraldo de la Tempestad", "Los dones de rayo salen un 75% más en el draft por rango.", 2, 1,
     [{"k": "draft.family.rayo", m: 0.75}], R("rayo_cd", 2))
pair(("rayo_verdugo", "rayo", "Rayo verdugo", "Un solo golpe letal: +15% de daño y +25% más contra los heridos por rango.", [{"k": "rayo.dmg", m: 0.15}, {"k": "special.rayo_exec", a: 0.25}]),
     ("rayo_chispa", "rayo", "Chispa incesante", "Rayos seguidos: -12% de enfriamiento y aturde 0,1 s más por rango.", [{"k": "rayo.cd", m: -0.12}, {"k": "rayo.stun", a: 0.1}]),
     R("rayo_exec", 1, "rayo_stun", 1))
# --- Demonio
ks("door_espinas", "demonio", "Puerta de espinas", "Quien golpea la Puerta recibe 14 de daño. A cambio la Puerta tiene un 25% menos de vida.",
   [{"k": "special.door_thorns", a: 14}, {"k": "door.hp", m: -0.25}], R("door_regen", 1))
boon("eco_avaricia", "demonio", "Pacto de Avaricia", "La resonancia Avaricia despierta con un solo don de almas.", 1, 1,
     [{"k": "set.need.alma", a: -1}], R("eco_reward", 2))
boon("door_bastion", "demonio", "Piedra del Bastión", "Los dones de Puerta salen un 50% más y la resonancia Bastión es un 50% más fuerte, por rango.", 2, 4,
     [{"k": "draft.family.puerta", m: 0.5}, {"k": "set.power.puerta", m: 0.5}], R("door_hp", 3))
pair(("door_baluarte", "demonio", "Baluarte", "La Puerta recibe un 10% menos de daño y recupera un 4% más tras cada oleada, por rango.", [{"k": "door.armor", m: -0.10}, {"k": "door.regen", a: 0.04}]),
     ("eco_mercader", "demonio", "Mercader de almas", "Sabuesos un 20% más baratos y +6 almas por oleada, por rango.", [{"k": "eco.sabueso_cost", m: -0.20}, {"k": "eco.wave_bonus", a: 6}]),
     R("door_regen", 2, "eco_level", 2))
# --- Bestias
ks("beast_tizon", "bestias", "Tizón inmortal", "Tizón no cae: si lo derriban, se levanta a los 4 s con media vida y sin cicatriz. Las demás bestias tienen un 40% menos de vida.",
   [{"k": "special.tizon_immortal", a: 1}, {"k": "special.others_hp", m: -0.4}], R("beast_hp", 3))
boon("beast_jauria", "bestias", "Sangre de Jauría", "La resonancia Jauría es un 50% más fuerte por rango.", 2, 1,
     [{"k": "set.power.bestia", m: 0.5}], R("beast_dmg", 2))
pair(("beast_horda", "bestias", "Horda", "Muchas y juntas: +3% de daño por cada otra bestia viva y +6% de velocidad, por rango.", [{"k": "special.pack", a: 0.03}, {"k": "beast.speed", m: 0.06}]),
     ("beast_alfa", "bestias", "Alfa", "Todo a Tizón: +20% de vida y de daño para él por rango.", [{"k": "special.named_hp", m: 0.2}, {"k": "special.named_dmg", m: 0.2}]),
     R("beast_pack", 1, "beast_scar", 1))
# --- Jauría
ks("sab_camada", "jauria", "Camada", "Cada Sabueso que reclutas llega con un gemelo gratis. A cambio los Sabuesos (menos Tizón) tienen un 35% menos de vida.",
   [{"k": "special.litter", a: 1}, {"k": "special.sab_hp", m: -0.35}], R("sab_hp", 2))
pair(("sab_cepo", "jauria", "Cepo", "La Presa dura un 20% más y llega un 10% más lejos, por rango.", [{"k": "sabueso.presa_time", m: 0.2}, {"k": "sabueso.presa_range", m: 0.1}]),
     ("sab_carnicero", "jauria", "Carnicero", "Sabuesos: +20% de daño y muerden un 8% más rápido, por rango.", [{"k": "sabueso.dmg", m: 0.2}, {"k": "sabueso.cd", m: -0.08}]),
     R("sab_desgarro", 1, "sab_leash", 1))
# --- Horno
ks("horno_ceniza", "horno", "Estallido de ceniza", "Con el Horno en pie, los enemigos que mueren ardiendo estallan: 14 de daño alrededor y prenden a los cercanos. A cambio el Horno tiene un 30% menos de vida.",
   [{"k": "special.burn_burst", a: 14}, {"k": "horno.hp", m: -0.3}], R("horno_burn", 2))
pair(("horno_boca", "horno", "Boca del Infierno", "+22% de daño de la llamarada por rango.", [{"k": "horno.spit_dmg", m: 0.22}, {"k": "horno.minor_dmg", m: 0.22}]),
     ("horno_fragua", "horno", "Fragua lenta", "El fuego del suelo dura un 40% más y quema un 20% más, por rango.", [{"k": "horno.ground_time", m: 0.4}, {"k": "horno.burn_dps", m: 0.2}]),
     R("horno_inhale_max", 2, "horno_ground", 1))
# --- Trueno
ks("trueno_errante", "trueno", "Tormenta errante", "El Trueno ya no vuelve a su puesto: lucha donde cae y salta desde allí, un 30% más a menudo. A cambio recibe un 30% más de daño.",
   [{"k": "special.trueno_roam", a: 1}, {"k": "trueno.jump_cd", m: -0.3}], R("trueno_cd", 2))
pair(("trueno_meteoro", "trueno", "Meteoro", "+25% de daño al aterrizar por rango.", [{"k": "trueno.land_dmg", m: 0.25}]),
     ("trueno_relampago", "trueno", "Relámpago en cadena", "+20% de daño y +10% de radio de las descargas, por rango.", [{"k": "trueno.chain_dmg", m: 0.2}, {"k": "trueno.chain_range", m: 0.1}]),
     R("trueno_chain_range", 1, "trueno_return", 1))
# --- Ojo
ks("ojo_fijo", "ojo", "Mirada fija", "El Ojo ya no encadena: concentra todo en un blanco, con +120% de daño.",
   [{"k": "special.ojo_focus", a: 1}, {"k": "ojo.dmg", m: 1.2}], R("ojo_dmg", 3))
pair(("ojo_vigia", "ojo", "Vigía", "+12% de daño y de alcance del Ojo por rango.", [{"k": "ojo.dmg", m: 0.12}, {"k": "ojo.range", m: 0.12}]),
     ("ojo_parpadeo", "ojo", "Parpadeo", "-10% de enfriamiento y +12% de daño de la cadena, por rango.", [{"k": "ojo.cd", m: -0.10}, {"k": "ojo.chain_dmg", m: 0.12}]),
     R("ojo_cd", 2, "ojo_range", 2))
# --- Abismo (se gana con el Alba)
B = "abismo"
node("abi_llamada", B, "Llamada del Abismo", "Gárgola, Enjambre y Garfio salen un 40% más en el draft por rango.", 2, 0,
     [{"k": "draft.kind.gargola", m: 0.4}, {"k": "draft.kind.enjambre", m: 0.4}, {"k": "draft.kind.garfio", m: 0.4}], [], 14, 6, boon=True)
node("abi_gargola_hp", B, "Piel de ceniza", "+12% de vida de la Gárgola por rango.", 4, 1, [{"k": "gargola.hp", m: 0.12}], R("abi_llamada", 1), 16, 4)
node("abi_enjambre_burn", B, "Moscas de ascua", "El Enjambre quema un 20% más fuerte y un 10% más de tiempo.", 4, 1, [{"k": "enjambre.burn_dps", m: 0.2}, {"k": "enjambre.burn_time", m: 0.1}], R("abi_llamada", 1), 16, 4)
node("abi_gargola_shock", B, "Onda de piedra", "+20% de daño y +8% de radio de la onda de la Gárgola.", 3, 2, [{"k": "gargola.shock_dmg", m: 0.2}, {"k": "gargola.shock_mult", m: 0.2}, {"k": "gargola.shock_r", m: 0.08}], R("abi_gargola_hp", 2), 22, 5)
node("abi_enjambre_n", B, "Nube espesa", "El Enjambre ataca a un enemigo más por rango.", 2, 2, [{"k": "enjambre.targets", a: 1}], R("abi_enjambre_burn", 2), 26, 8)
node("abi_garfio_cd", B, "Cadena engrasada", "-10% de enfriamiento del gancho por rango.", 4, 3, [{"k": "garfio.hook_cd", m: -0.1}], R("abi_gargola_hp", 1), 22, 5)
node("abi_garfio_stun", B, "Anzuelo cruel", "El gancho aturde 0,3 s más y hace un 50% más de daño.", 3, 3, [{"k": "garfio.hook_stun", a: 0.3}, {"k": "garfio.hook_dmg", m: 0.5}], R("abi_enjambre_burn", 1), 22, 5)
ks("abi_pacto", B, "Pacto del Abismo", "Empiezas cada partida con una bestia del Abismo al azar. A cambio empiezas sin almas.",
   [{"k": "special.abismo_start", a: 1}], R("abi_llamada", 2))
pair(("abi_guardia", B, "Guardia de piedra", "Gárgola y Garfio: +18% de vida por rango.", [{"k": "gargola.hp", m: 0.18}, {"k": "garfio.hp", m: 0.18}]),
     ("abi_plaga", B, "Plaga ardiente", "El Enjambre ataca un 15% más a menudo y sus moscas hacen un 50% más de daño, por rango.", [{"k": "enjambre.cd", m: -0.15}, {"k": "enjambre.swarm_dmg", m: 0.5}]),
     R("abi_garfio_cd", 1, "abi_garfio_stun", 1))
# --- Inquisición (se gana con el tercer asedio)
B = "inquisicion"
node("inq_trofeos", B, "Trofeos de guerra", "+6% de esencia por oleada superada, por rango.", 3, 0, [{"k": "meta.wave", m: 0.06}], [], 14, 6)
node("inq_hereje", B, "Hierro hereje", "Héroes y jefes reciben un 6% más de daño por rango.", 4, 1, [{"k": "special.vs_big", a: 0.06}], R("inq_trofeos", 1), 16, 4)
node("inq_velo", B, "Velo de ceniza", "Los santuarios curan a los humanos y queman a tus bestias un 20% menos por rango.", 3, 1, [{"k": "special.sanct", m: -0.2}], R("inq_trofeos", 1), 16, 4)
node("inq_sellos", B, "Quiebrasellos", "Los escudos sagrados de los enemigos aguantan un 20% menos por rango.", 3, 2, [{"k": "special.shield", m: -0.2}], R("inq_hereje", 1), 22, 5)
node("inq_notario", B, "Notario infernal", "Los encargos pagan un 20% más por rango.", 3, 2, [{"k": "special.contract", m: 0.2}], R("inq_velo", 1), 22, 5)
node("inq_sordo", B, "Sordo al Juicio", "El Juicio de los jefes hace un 15% menos de daño por rango.", 3, 3, [{"k": "special.judge", m: -0.15}], R("inq_sellos", 1), 22, 5)
node("inq_profeta", B, "Lengua de profeta", "Los dones épicos salen un 30% más en el draft por rango.", 2, 3, [{"k": "draft.rarity.epica", m: 0.3}], R("inq_notario", 1), 26, 8, boon=True)
ks("inq_hoguera", B, "Hoguera profana", "En cada oleada arde una hoguera ante la Puerta que cura a tus bestias y quema a los humanos. A cambio la Puerta tiene un 20% menos de vida.",
   [{"k": "special.profane", a: 1}, {"k": "door.hp", m: -0.2}], R("inq_velo", 2))
pair(("inq_fuego", B, "Fuego sagrado", "Los enemigos que arden reciben un 8% más de daño por rango.", [{"k": "special.burn_vuln", a: 0.08}]),
     ("inq_cadenas", B, "Cadenas benditas", "Los enemigos aturdidos o retenidos reciben un 12% más de daño por rango.", [{"k": "special.stun_vuln", a: 0.12}]),
     R("inq_sordo", 1, "inq_profeta", 1))

json.dump(d, open(P, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(d["nodes"]), "nodos,", len(d["branches"]), "ramas")
