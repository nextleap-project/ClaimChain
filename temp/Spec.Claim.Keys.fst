module Spec.Claim.Keys

open FStar.Seq
open FStar.List.Tot

open Spec.Claim.Common

type keyEnt = 
|InitKeyEnt : source: string -> key: bytes -> keyEnt
|PkSig: key : bytes -> keyEnt
|PkVRF : key : bytes -> keyEnt 
|PkDH : key : bytes -> keyEnt

val getKeyAsBytes: k: keyEnt -> Tot bytes
let getKeyAsBytes k = 
    match k with 
    | InitKeyEnt _ key -> key 
    | PkSig key -> key
    | PkVRF key -> key
    | PkDH key -> key

val isKeyEntPkSig: k: keyEnt -> Tot bool
let isKeyEntPkSig k = 
    match k with 
    |PkSig _ -> true 
    |_ -> false


val isKeyEntPkVRF: k: keyEnt -> Tot bool
let isKeyEntPkVRF k = 
    match k with 
    |PkVRF _ -> true 
    |_ -> false

val isKeyEntPkDH: k: keyEnt -> Tot bool
let isKeyEntPkDH k = 
    match k with 
    |PkDH _ -> true 
    |_ -> false

type cryptoKeyEnt = 
| CryptoKeyEnt : keys: list keyEnt
    {
        (existsb isKeyEntPkSig keys) /\
        (existsb isKeyEntPkDH keys) /\
        (existsb isKeyEntPkVRF keys) /\ 
        length keys > 0
    } -> cryptoKeyEnt

val keySearchPkSig: l: list keyEnt {existsb isKeyEntPkSig l /\ length l > 0} -> Tot(r: keyEnt{isKeyEntPkSig r})
let rec keySearchPkSig l = 
    if (List.length l = 1) then hd l
    else    
        match l with
        | hd::tl -> if isKeyEntPkSig hd then hd else keySearchPkSig tl

val crKeySearchPkSig: l: cryptoKeyEnt -> Tot (r: keyEnt {isKeyEntPkSig r})
let crKeySearchPkSig l = 
    let keys = l.keys in 
    keySearchPkSig keys

val keySearchPkDH: l: list keyEnt {existsb isKeyEntPkDH l /\ length l > 0} -> Tot (r: keyEnt{isKeyEntPkDH r})
let rec keySearchPkDH l = 
    if (List.length l = 1) then hd l
    else    
        match l with
        | hd::tl -> if isKeyEntPkDH hd then hd else keySearchPkDH tl

val keySearchPkVRF: l: list keyEnt {existsb isKeyEntPkVRF l /\ length l > 0} -> Tot (r: keyEnt{isKeyEntPkVRF r})
let rec keySearchPkVRF l = 
    if (List.length l = 1) then hd l
    else    
        match l with
        | hd::tl -> if isKeyEntPkVRF hd then hd else keySearchPkVRF tl     