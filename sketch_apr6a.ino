#include <Arduino.h>

// Increased buffer size and timeout
#define BUFFER_SIZE 128
#define READ_TIMEOUT 500  // Increased from 200ms
uint8_t serialBuffer[BUFFER_SIZE];
uint8_t bufHead = 0;
uint8_t bufTail = 0;

void handleSerial1() {
  while(Serial1.available()) {
    // Handle buffer wrap-around safely
    uint8_t nextHead = (bufHead + 1) % BUFFER_SIZE;
    if(nextHead != bufTail) {
      serialBuffer[bufHead] = Serial1.read();
      bufHead = nextHead;
    }
  }
}

uint16_t readResponse() {
  unsigned long start = millis();
  while(millis() - start < READ_TIMEOUT) {
    handleSerial1();
    if((bufHead - bufTail) >= 2) {
      uint8_t high = serialBuffer[bufTail];
      bufTail = (bufTail + 1) % BUFFER_SIZE;
      uint8_t low = serialBuffer[bufTail];
      bufTail = (bufTail + 1) % BUFFER_SIZE;
      return (high << 8) | low;
    }
  }
  return 0xFFFF; // Timeout indicator
}

void setup() {
  Serial.begin(115200);
  Serial1.begin(57600);  // Reduced baud rate for stability
  while(!Serial); // Wait for USB connection
}

void loop() {
  if(Serial.available() > 0) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toUpperCase();

    if(cmd.startsWith("W") && cmd.length() == 11) {
      // Write command: W000000A55A
      uint32_t addr = strtoul(cmd.substring(1,7).c_str(), NULL, 16);
      uint16_t data = strtoul(cmd.substring(7).c_str(), NULL, 16);
      
      // Clear buffer before new transaction
      bufHead = bufTail = 0;
      
      Serial1.write('W');
      Serial1.write(addr >> 16);
      Serial1.write(addr >> 8);
      Serial1.write(addr);
      Serial1.write(data >> 8);
      Serial1.write(data);
      
      Serial.print("Write @");
      Serial.print(addr, HEX);
      Serial.print(": ");
      Serial.println(data, HEX);  // Removed '0x' prefix
    }
    else if(cmd.startsWith("R") && cmd.length() == 7) {
      // Read command: R000000
      uint32_t addr = strtoul(cmd.substring(1).c_str(), NULL, 16);
      bool success = false;
      
      // Increased retries with delay
      for(uint8_t retry=0; retry<8; retry++) {
        bufHead = bufTail = 0;  // Reset buffer before each attempt
        
        Serial1.write('R');
        Serial1.write(addr >> 16);
        Serial1.write(addr >> 8);
        Serial1.write(addr);
        
        uint16_t data = readResponse();
        if(data != 0xFFFF) {
          Serial.print("Data @");
          Serial.print(addr, HEX);
          Serial.print(": ");
          Serial.println(data, HEX);  // Matched output format
          success = true;
          break;
        }
        delayMicroseconds(50);  // Added between retries
      }
      
      if(!success) {
        Serial.print("Read @");
        Serial.print(addr, HEX);
        Serial.println(": Timeout");
      }
    }
  }
  
  handleSerial1(); // Maintain buffer processing
}
