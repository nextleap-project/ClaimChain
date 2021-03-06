module Spec.VRF

open FStar.UInt32
open FStar.UInt8
open FStar.Seq
open FStar.Option

open FStar.Mul
open FStar.Seq
open FStar.UInt


open FStar.Endianness
open Spec.Curve25519
open Spec.Ed25519
(*)
open Spec.SHA2_256
*)

#set-options "--max_fuel 0 --initial_fuel 0"

let bytes =  seq FStar.UInt8.t
let key = lbytes 32
let field = prime

let n = 32

let positive_point_const = Seq.create 1 2uy
let negative_point_const = Seq.create 1 3uy

type twisted_edward_point = ext_point

val scalarMultiplication : point : twisted_edward_point -> k: bytes -> Tot twisted_edward_point
let scalarMultiplication point k = 
	Spec.Ed25519.point_mul k point

val scalarAddition : p : twisted_edward_point -> q: twisted_edward_point -> Tot twisted_edward_point
let scalarAddition p q = 
	Spec.Ed25519.point_add p q 

val isPointOnCurve: point : option twisted_edward_point -> Tot bool
let isPointOnCurve point =
	if isNone point then false else
	let point = get point in 
	let px, py, pz, pt = point in 
	let zinv = modp_inv pz in 
	let x = fmul px zinv in 
	let y = fmul py zinv in 
	let x2 = fmul x x in 
	let x3 = fmul x2 x in 
	let y2 = fmul y y in 
	let ax2 = fmul 486662 x2 in 
	let r = y2 - x3 - ax2 - x in 
	(r%prime) = 0

val serializePoint : point: twisted_edward_point -> Tot bytes
let serializePoint point = point_compress point

val deserializePoint : b: bytes{Seq.length b = 32} -> Tot (option twisted_edward_point)
let deserializePoint b = point_decompress b

val _OS2ECP : point: bytes{Seq.length point = 32} -> Tot(option twisted_edward_point)
let _OS2ECP point = deserializePoint point

val _ECP2OS : gamma: twisted_edward_point -> Tot(r: bytes {Seq.length r = 32})
let _ECP2OS gamma = serializePoint gamma

val nat_to_uint8: x: int {x < 256} -> Tot(FStar.UInt8.t)
let nat_to_uint8 x = FStar.UInt8.uint_to_t (to_uint_t 8 x)

val uint8_to_int : x: FStar.UInt8.t -> Tot(int)
let uint8_to_int x = FStar.UInt8.v x

val _helper_I2OSP: value: nat -> s: bytes -> counter : nat {counter < Seq.length s} -> 
		Tot (r: bytes {Seq.length r = Seq.length s})(decreases (Seq.length s - counter))
let rec _helper_I2OSP value s counter  = 
	let mask = 256 in 
	let r = value % mask in 
	let r = nat_to_uint8 r in 
	let s = upd s counter r in 
	let number = value / mask  in 
		if (counter +1 <Seq.length s) then 
			_helper_I2OSP value s (counter +1)
		else s

val _I2OSP: value: nat -> n: int{n > 0} -> Tot(r: bytes{Seq.length r = n})
let _I2OSP value n = 
	if (pow2 n <= value) then Seq.create n 0uy
	else 
		let s = Seq.create n 0uy in 
		 (_helper_I2OSP value s 0)

val _helper_OS2IP: s: bytes  -> counter: nat {counter < Seq.length s} -> number: nat -> 
	Tot (nat)(decreases (Seq.length s - counter))
let rec _helper_OS2IP s counter number = 
	let temp = Seq.index s counter in 
	let temp = uint8_to_int temp in 
	let number = number + (op_Multiply (pow2 8*counter) temp) in 
	if (counter + 1 = Seq.length s) then 
		number 
	else _helper_OS2IP s (counter+1) number

val _OS2IP: s: bytes{Seq.length s > 0} -> nat

let _OS2IP s = 
	_helper_OS2IP s 0 0

val seqConcat : s1: seq 'a -> s2: seq 'a -> 
			Tot(r:seq 'a{Seq.length	r = Seq.length s1 + Seq.length s2})

let seqConcat s1 s2 = 
	FStar.Seq.append s1 s2 	

val hash: input: bytes{Seq.length input < Spec.SHA2_256.max_input_len_8} -> 
		Tot(r: bytes{Seq.length r = Spec.SHA2_256.size_hash})	
let hash input = 
	Spec.SHA2_256.hash input

#set-options "--initial_ifuel 1 --max_ifuel 1 --initial_fuel 0 --max_fuel 0 --z3rlimit 30"


val _ECVRF_decode_proof: 
		pi: bytes {Seq.length pi = op_Multiply 4 n} -> 
		Tot(tuple3 (option twisted_edward_point) (c:bytes{Seq.length c = n}) (s:bytes {Seq.length s = (op_Multiply 2 n)}))
		 (* due to the fact that
		 we do point multiplication using seq of bytes, 
		the operation to cast the value to int and to sequence 
		back is decided to be needless*)

let _ECVRF_decode_proof pi = 
	let gamma, cs = Seq.split pi n in 
		assert(Seq.length gamma = n);
		assert(Seq.length cs = op_Multiply 3 n);
	let c, s = Seq.split cs n in 
		assert(Seq.length c = n);
		assert(Seq.length s = op_Multiply 2 n);
	let point = _OS2ECP gamma in 
	(point, c, s)

#reset-options


val _helper_ECVRF_hash_to_curve : 
	ctr : nat{ctr < field} ->counter_length:nat{counter_length > 0} ->  
	pk: bytes{Seq.length pk = 32} ->
	input: bytes{Seq.length input < Spec.SHA2_256.max_input_len_8 - 32 - counter_length } ->
	Tot(r: option twisted_edward_point {Some?r ==> isPointOnCurve r}) 
	(decreases(field - ctr)) 

let rec _helper_ECVRF_hash_to_curve ctr counter_length pk input = 
	let _CTR = _I2OSP ctr counter_length in 
	let toHash = seqConcat input pk in 
	let toHash = seqConcat toHash _CTR in (* point nonce *)
	let hash = hash toHash in
	(*let possible_point = seqConcat positive_point_const hash in*) (* this one was deleted becauce of decompression func *) 
	(*let possible_point = _OS2ECP possible_point in *)
	let possible_point = _OS2ECP hash in 
	if isNone possible_point then None else
		if isPointOnCurve possible_point then possible_point
		else
			if (ctr +1) < field
				then (
					assert((ctr+1) <field);
					_helper_ECVRF_hash_to_curve (ctr+1) counter_length pk input)
			else None	

val _ECVRF_hash_to_curve: input: bytes{Seq.length input < Spec.SHA2_256.max_input_len_8 - 36 } -> 
			public_key: (twisted_edward_point) -> Tot(option twisted_edward_point)			

let _ECVRF_hash_to_curve input public_key = 
	let ctr = 0 in 
	let pk = _ECP2OS public_key in 
	let point = _helper_ECVRF_hash_to_curve ctr 4 pk input in point

assume val random: 	max: nat -> Tot(random : nat {random > 0 /\ random < max})	

val randBytes: max: nat -> Tot(r:bytes{Seq.length r = 32})
let randBytes max = 
	let rand = random max in _I2OSP rand 32 (* in octets = log_2 field / 8  *)

val _ECVRF_hash_points : generator: twisted_edward_point -> h:  twisted_edward_point -> 
			public_key: twisted_edward_point -> gamma : twisted_edward_point -> 
			gk : twisted_edward_point -> hk : twisted_edward_point -> 
			Tot(nat)

let _ECVRF_hash_points generator h public_key gamma gk hk = 
	let p = _ECP2OS generator in (*32 *)
	let p = seqConcat p (_ECP2OS h) in (* 64  *)
	let p = seqConcat p (_ECP2OS public_key) (* 32*3 *) in 
	let p = seqConcat p (_ECP2OS gamma)  (* still less than 2pow 61 *)in 
	let p = seqConcat p (_ECP2OS gk) in 
	let p = seqConcat p (_ECP2OS hk) in 
	let h' = hash p in 
	let h = fst (FStar.Seq.split h' n) in 
	_OS2IP h

val _ECVRF_prove: input: bytes {Seq.length input < Spec.SHA2_256.max_input_len_8 - 36 } ->  public_key: twisted_edward_point -> 
			private_key : bytes (* private key in this scope is a mupliplier of the generator *)
			-> generator : twisted_edward_point->  
			Tot(proof: option bytes {Some?proof ==> Seq.length (Some?.v proof) = op_Multiply 4 n})
			(*Tot(proof: option bytes{Seq.length proof = 5 * n + 1})  *)

let _ECVRF_prove input public_key private_key generator = 
	let h = _ECVRF_hash_to_curve input public_key in 
		if isNone h then None (* trying to convert the hash to point, if it was not possible returns None *)
		else 
			let h = get h in 
	let gamma = scalarMultiplication h private_key in 
	let k_ = random field in 
	let k =  _I2OSP k_ 32 in  (* random in sequence  *)
		let gk = scalarMultiplication generator k in  (* k< (2^8)^32 = 2^(8*32) = 2^(2^3 * 2^ 5 = 256) *) (* *)
		let hk = scalarMultiplication h k in 
	let c = _ECVRF_hash_points generator h public_key gamma gk hk in (*int*)
			let cq = op_Multiply c field in  (*int*)
			let cqmodq = cq % field in 
			assert(cqmodq < field);
			assert(k_ <field); 
			assert(k_ + field > field); (* I assume that the operations are done in the field. *)
	let k_ = k_ + field in 		
			(* random was generated in the seq -> cast to nat *)
	let s = k_ - cqmodq (* int *) in (*cqmodq is < field *)
	assert (s > 0);
			let fst = _ECP2OS gamma in (*32*)
			let snd = _I2OSP c n in (* Seq length snd = n*)
			let thd = _I2OSP s ( op_Multiply 2 n) (* Seq.length thr = 2n *) in 
	let pi = seqConcat fst (seqConcat snd thd) in Some pi


val _ECVRF_proof2hash: pi: bytes{Seq.length pi = op_Multiply 4 n } -> Tot(hash: bytes{Seq.length hash = n})
let _ECVRF_proof2hash pi = fst( Seq.split pi n)

val _ECVRF_verify : generator: twisted_edward_point ->  public_key : twisted_edward_point ->
		pi: bytes {Seq.length pi = op_Multiply 4 n } -> 
		input : bytes{Seq.length input < Spec.SHA2_256.max_input_len_8 - 36 } -> 
		Tot(bool)

let _ECVRF_verify generator public_key pi input = 
	let gamma, c, s = _ECVRF_decode_proof pi in 
	if not(isPointOnCurve gamma) then false else
	if isNone gamma then false
		else let gamma = get gamma in 
	let pkc = scalarMultiplication public_key c in 
	let gs = scalarMultiplication generator s in 
	let u  = scalarAddition pkc gs in 
	let h = _ECVRF_hash_to_curve input public_key in 
		if isNone h then false
	else 
	let h = get h in 
	let gammac = scalarMultiplication gamma c in 
	let hs = scalarMultiplication h s in 
	let v = scalarAddition gammac hs in 
	let c_prime = _ECVRF_hash_points generator h public_key gamma u v in 
	(_OS2IP c) = c_prime
