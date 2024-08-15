<CsoundSynthesizer>
<CsOptions>
-odac -d
</CsOptions>
<CsInstruments>

sr = 44100
ksmps = 10
nchnls = 2
0dbfs = 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; global variables
giOSC       OSCinit  	9898
gkGainScl   init      1      ;; global gain
gkHzScl     init      1      ;; global pitchshift
gkRateScl   init      1      ;; global playback rate
gkDurScl    init      1      ;; global PVX file duration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

gSpvx					  init					"portrait13A_4096_ampRank.pvx" ;; default PVX file

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
       instr 1     ;; Initialize Instrument
                   ;; this is used with the voxels. (But not when simulating on one machine)
                   ;; it receives the speaker assignments for the voxel and then creates 
                   ;; the standard OSC listening instr (2) with the speaker numbers hard-coded
                   ;; (this is necessary because the OSClisten opcode expects i-rate tags
                
       
kSpeakerA init 999
kSpeakerB init 999       
kActive   init 0
         
listenerSimpleSco:    
   
kScore 	OSClisten giOSC, "/speakers" , "ii", kSpeakerA, kSpeakerB 
						if (kScore == 0 ) goto default
						
						if( kActive == 1 ) then  ; if there is a controller playing, turn it off
									event "i", -2.1, 0, -1, kSpeakerA, kSpeakerB; the sco event
									kActive = 0
						endif
						
						if( kActive == 0 ) then ; if no controller is already playing, start one
						    event "i",  2.1, 0, -1, kSpeakerA, kSpeakerB; the sco event
						    kActive = 1
						endif

						kgoto listenerSimpleSco 				; loop back to top to check for more messages								
default:
       endin
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		 				instr 2	; CONTROL INSTRUMENT
		 										; triggers instance of sounding instrument (i20)
ispeakerID_A =     p4
ispeakerID_B =     p5
iGainA       =					0.5			; gain for bin1
iGainB       =	     0.5		; gain for bin2 (should usually be the same)
instrBase    =     19   ; playback instr number
instrA       =     instrBase + (ispeakerID_A/100.0)
instrB       =     instrBase + (ispeakerID_B/100.0)

kTestHzA     init     300 + (ispeakerID_A * 25 ) ; frequency currently hard set as a test
kTestHzB     init     300 + (ispeakerID_B * 25 ) ; frequency currently hard set as a test

ScoInit      init   "/sco/"
ScueInit     init   "/cue/"
SplayInit    init   "/play/"
SbinsInit    init  "/linbin/"
SwindowInit  init  "/window/"
Soff         init  "i -"

ScoA         sprintfk  "%s%d" , ScoInit,     ispeakerID_A
ScoB         sprintfk  "%s%d" , ScoInit,     ispeakerID_B 
ScueA        sprintfk  "%s%d" , ScueInit,    ispeakerID_A
ScueB        sprintfk  "%s%d" , ScueInit,    ispeakerID_B 
SplayA       sprintfk  "%s%d" , SplayInit,   ispeakerID_A
SplayB       sprintfk  "%s%d" , SplayInit,   ispeakerID_B 
SbinsA       sprintfk  "%s%d" , SbinsInit,   ispeakerID_A
SbinsB       sprintfk  "%s%d" , SbinsInit,   ispeakerID_B 
SwindowA     sprintfk  "%s%d" , SwindowInit, ispeakerID_A
SwindowB     sprintfk  "%s%d" , SwindowInit, ispeakerID_B 
          
ScoEventA    init  " "
ScoEventB    init  " "
SnoteOffA    init  " "
SnoteOffB    init  " "
kActiveB     init  0
kActiveA     init  0
kCuedA       init  0
kCuedB       init  0
kplay	        init  0
kplayA       init  0
kplayB       init  0
kSync        =     0


;; OSC listeners
;;;------------------------------------------------------------------------;;;						
;;;------------------------------------------------------------------------;;;						
listenerScoA:
kBscoA		OSClisten giOSC, ScoA, "s", ScoEventA
        if (kBscoA == 0 ) goto listenerScoB
						scoreline ScoEventA, 1
						kActiveA = 1
						kCuedA   = 1
						kgoto listenerScoA

;;;------------------------------------------------------------------------;;;
listenerScoB:						
listenerScoB:
kBscoB		OSClisten giOSC, ScoB, "s", ScoEventB
        if (kBscoB == 0 ) goto listenerScueA
						scoreline ScoEventB, 1
						kActiveB = 1
						kCuedB   = 1            
						kgoto listenerScoB
						
		
;;;------------------------------------------------------------------------;;;						
listenerScueA:
kBcueA		OSClisten giOSC, ScueA, "s", ScoEventA ; load up a score event but don't play it
        if (kBcueA == 0 ) goto listenerScueB
        if( kBcueA == 1 ) then
        kCuedA = 1
        endif 
						kgoto listenerScueA

;;;------------------------------------------------------------------------;;;
listenerScueB:						
kBcueB		OSClisten giOSC, ScueB, "s", ScoEventB ; load up a score event but don't play it
        if (kBcueB == 0 ) goto listenerPlayA
        kCuedB = 1        
        kgoto listenerScueB						
						 
					
;;;------------------------------------------------------------------------;;;
listenerPlayA:           ;; Access: Broadcast to all PIs, only this PI listens 
                         ;; play on / off for speaker A 
                         ;; for example, if this is speaker 7:
                         ;; "play/7/1" will play this speaker and only this speaker
                         ;; "play/7/0" will turn off this speaker and only this speaker
                         
kBplayA	OSClisten giOSC, SplayA , "i", kplayA
						if (kBplayA == 0 ) goto listenerPlayB

	    					if (kplayA > 0 && kCuedA == 1) then  ; it's off, turn it on
                          scoreline ScoEventA, 1
                          kActiveA  = 1
						    endif		
				
						if (kplayA == 0 && kActiveA == 1) then		; it's on, turn it off
            klenA         strlenk   ScoEventA
            SpFieldsA     strsubk   ScoEventA,2,klenA
            SnoteOffA     strcatk   Soff, SpFieldsA
                          scoreline SnoteOffA, 1
                          kActiveA  = 0
                          
						endif
						kgoto listenerPlayA 				; loop back to top to check for more messages	

;;;------------------------------------------------------------------------;;;
listenerPlayB:           ;; Access: Broadcast to all PIs, only this PI listens
                         ;; play on / off for speaker B 
                         ;; for example, if this is speaker 10:
                         ;; "play/10/1" will play this speaker and only this speaker
                         ;; "play/10/0" will turn off this speaker and only this speaker
                         
kBplayB	OSClisten giOSC, SplayB , "i", kplayB
						if (kBplayB == 0 ) goto listenerPlay

	    					if (kplayB > 0 && kCuedB == 1 ) then   ; it's off, turn it on
 				    					 scoreline ScoEventB, 1
 				    					 kActiveB = 1         
						    endif		
						
				if (kplayB == 0 && kActiveB == 1 ) then		; it's on, turn it off
				        
            klenB     strlenk   ScoEventB
            SpFieldsB strsubk   ScoEventB,2,klenB
            SnoteOffB strcatk   Soff, SpFieldsB
                      scoreline SnoteOffB, 1
            kActiveB  = 0
						endif
						
						kgoto listenerPlayB 				; loop back to top to check for more messages	
																
;;;;------------------------------------------------------------------------;;;
;;;;--- GLOBAL VARIABLE LISTENERS    ---------------------------------------;;;
;;;;------------------------------------------------------------------------;;;

;; NOTE: When simulating this on a single machine (by making explicit score statements using instr 2)
;; listenerPlay and listenerSyncPhase will not work the way they are supposed to, 
;; because only *one* instance
;; of the score statement handles globally broadcast messages. Once it is received, 
;; no other instance can see it. This will not be a problem on the voxels.

;;;------------------------------------------------------------------------;;;
listenerPlay:           ;; Access: Broadcast to all PIs, all PIs listen
                        ;; Listener 0 listens for the /play command [1,0]
								              ;; 1 - trigger two instaces i22 that plays forever (negative p3 value)
								              ;; 0 - trigger two 'note offs' for i22 (negative p1 value)
								 
kBplay		OSClisten giOSC, "/play", "i", kplay
						if (kBplay == 0 ) goto listenerGlobal


						if (kplay > 0 && kCuedA == 1) then
											  scoreline ScoEventA, 1
											  kActiveA = 1
						endif
						
						if (kplay > 0 && kCuedB == 1) then
											  scoreline ScoEventB, 1
											  kActiveB = 1
						endif

						if (kplay == 0 && kActiveA == 1) then		
            klenA         strlenk   ScoEventA
            SpFieldsA     strsubk   ScoEventA,2,klenA
            SnoteOffA     strcatk   Soff, SpFieldsA
                          scoreline SnoteOffA, 1
            kActiveA      =         0
						endif

						if (kplay == 0 && kActiveB == 1) then		
            klenB     strlenk ScoEventB
            SpFieldsB strsubk ScoEventB,2,klenB
            SnoteOffB strcatk Soff, SpFieldsB
            scoreline SnoteOffB, 1
            kActiveB  = 0
						endif						
						
						kgoto listenerPlay 				; loop back to top to check for more messages	



;;;;------------------------------------------------------------------------;;;
;;;;------------------------------------------------------------------------;;;

listenerGlobal: ;; ListenerGlobal listens for the /global command
								      ;; which contains Gain, Frequency Scale [0.0-1.0], Duration Scale, and Playback Rate
                ;; a continuous value that rides the gain of both oscillators							
                 
kBglobal	OSClisten giOSC, "/global", "ffff", gkGainScl,gkHzScl,gkDurScl,gkRateScl
							if (kBglobal == 0 ) goto listenerSyncPhase	
							kgoto listenerGlobal
						
;;;------------------------------------------------------------------------;;;
listenerSyncPhase:		;; Listener 4 listens for the /sync command [any value acts as a trigger]
								          ;; this resets the phasor to 0. if oscillators get out of sync from each
								          ;; other over time, this will (hopefully) realign them. 
								          
kBSync			OSClisten giOSC, "/sync"	, "i", kSync
							if (kBSync == 0 ) goto listenerPVXFile	
							
							if (kActiveA == 1 ) then 
	    					    klenA      strlenk   ScoEventA
	    					    SpFieldsA  strsubk   ScoEventA,2,klenA
	    					    SnoteOffA  strcatk   Soff, SpFieldsA
	    					               scoreline SnoteOffA, 1  
	    					               scoreline ScoEventA, 1
							endif
							
							if (kActiveB == 1 ) then 
             klenB       strlenk   ScoEventB
             SpFieldsB   strsubk   ScoEventB,2,klenB
             SnoteOffB   strcatk   Soff, SpFieldsB
                         scoreline SnoteOffB, 1  
                         scoreline ScoEventB, 1
							endif
							
							kgoto listenerSyncPhase
							
							
	;;;------------------------------------------------------------------------;;;
listenerPVXFile:		;; Listener 4 listens for the /sync command [any value acts as a trigger]
								          ;; this resets the phasor to 0. if oscillators get out of sync from each
								          ;; other over time, this will (hopefully) realign them. 
								          
kBpvx			OSClisten giOSC, "/pvx"	, "s", gSpvx
							if (kBpvx == 0 ) goto default	
							printks gSpvx, 1
							kgoto listenerPVXFile
							
default:
										 
		 				endin
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
								instr 19 ; simple oscil

iGain     =          p4
iHz       =          p5
iGate     =          p6

aSmooth   linsegr    0,0.01,1,p3-0.01,1,0.01,0 ;; clean on/off edges
aSig      oscil      iGain*gkGainScl, iHz*gkHzScl, 1
          outs       aSig*aSmooth*(1-iGate), aSig*aSmooth*(iGate)								
								endin								
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
          instr 20

iBin      =      p4-1
iGate     =      p5


ipvDur				filelen		   gSpvx
kpvDur				=					    	ipvDur 			 * gkDurScl				;scale the duration
kpvHz					=						   (1/kpvDur)  * gkRateScl			;scale the playback rate

kIndx     phasor      kpvHz
kf,ka     pvread      kIndx*kpvDur, gSpvx, iBin
aa        butlp       a(ka), 200
af        butlp       a(kf), 200
ka        =           k(aa)
kf        =           k(af)
          
aSmooth   linsegr    0,0.01,1,p3-0.01,1,0.01,0 ;; clean on/off edges
aSig      oscili     ka*gkGainScl, kf*gkHzScl, 1
          outs       aSig*aSmooth*(1-iGate), aSig*aSmooth*(iGate)								
          
          endin          
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




</CsInstruments>
<CsScore>

f1 0 4097 10 1
f0 648000 ; keep csound 'on' for a month 30*24*60*60

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; i1 is the version for running on the voxels
;; * comment it out when simulating on one machine
;; * uncomment it for running on the voxels

i1.1 0 -1; keep control instrument on indefinitely 


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; * uncomment these i2 statements to simulate on one machine
;; * be sure to comment these out when running on voxels
;;
;; note that the standard /play and /sync commands
;; will not work the way they are supposed to
;; but they will work on the voxels.

;; speakers 1 - 8
/*i2.1  0 -1  1  2
i2.2  0 -1  3  4
i2.3  0 -1  5  6
i2.4  0 -1  7  8

;; speakers 9 - 16
i2.5  0 -1  9 10
i2.6  0 -1 11 12
i2.7  0 -1 13 14
i2.8  0 -1 15 16

;; speakers 17 - 32

i2.9  0 -1 17 18
i2.10 0 -1 19 20
i2.11 0 -1 21 22
i2.12 0 -1 23 24
i2.13 0 -1 25 26
i2.14 0 -1 27 28
i2.15 0 -1 29 30
i2.16 0 -1 31 32
*/


</CsScore>
</CsoundSynthesizer>




































































<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>100</x>
 <y>100</y>
 <width>320</width>
 <height>240</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="nobackground">
  <r>255</r>
  <g>255</g>
  <b>255</b>
 </bgcolor>
</bsbPanel>
<bsbPresets>
</bsbPresets>
