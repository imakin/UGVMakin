
#define STICK_THRESHOLD_DIST 300
#define STICK_THRESHOLD_H 512+STICK_THRESHOLD_DIST
#define STICK_THRESHOLD_L 512-STICK_THRESHOLD_DIST

#define NMCU_D7 9 //left
#define NMCU_D6 8 //right
#define NMCU_D5 7 //forward
#define NMCU_D0 6 //backward

#define NMCU_LEFT NMCU_D7
#define NMCU_RIGHT NMCU_D6
#define NMCU_FORWARD NMCU_D5
#define NMCU_BACKWARD NMCU_D0

#define DEBUG 0
#ifdef DEBUG
  #define ngeprintln(x) Serial.println(x)
  #define ngeprint(x) Serial.print(x)
#else
  #define ngeprintln(x) ;
  // #define ngeprint(x) ;
#endif


void setup() {
    Serial.begin(115200);
    pinMode(NMCU_D0,1);
    pinMode(NMCU_D5,1);
    pinMode(NMCU_D6,1);
    pinMode(NMCU_D7,1);
    digitalWrite(NMCU_D0,1);
    digitalWrite(NMCU_D5,1);
    digitalWrite(NMCU_D6,1);
    digitalWrite(NMCU_D7,1);
}

void loop() {
    //asking nodemcu to calculate quick maffs
    int a0 = analogRead(A0);
    int a1 = analogRead(A1);
    int a2 = analogRead(A2);
    int a3 = analogRead(A3);
    
    /**
     * JR joystick kiri
     * JL joystick kanan
     * A1
     * 1024
     *  |
     *  |
     *  |       A3 0 ------ 1024 A3
     *  |
     *  0
     * A1
     * 
     */
    if (a1>STICK_THRESHOLD_H) {
      digitalWrite(NMCU_FORWARD, 0);
      // Serial.println("maju");
    }
    else {
      digitalWrite(NMCU_FORWARD, 1);
    }
    
    if (a1<STICK_THRESHOLD_L) {
      digitalWrite(NMCU_BACKWARD, 0);
      // Serial.println("mundur");
    }
    else {
      digitalWrite(NMCU_BACKWARD, 1);
    }
    
    if (a3>STICK_THRESHOLD_H) {
      digitalWrite(NMCU_RIGHT, 0);
      // Serial.println("kanan");
    }
    else {
      digitalWrite(NMCU_RIGHT, 1);
    }
    if (a3<STICK_THRESHOLD_L) {
      digitalWrite(NMCU_LEFT, 0);
      // Serial.println("kiri");
    }
    else {
      digitalWrite(NMCU_LEFT, 1);
    }
    
    // Serial.print("A0: ");Serial.println(a0);
    // Serial.print("A1: ");Serial.println(a1);
    // Serial.print("A2: ");Serial.println(a2);
    // Serial.print("A3: ");Serial.println(a3);
    // delay(1000);
}
