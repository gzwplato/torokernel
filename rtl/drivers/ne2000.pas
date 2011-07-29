//
// ne2000.pas
//
// Driver for ne2000 Network Card.
// For the moment just detect one card.
//
// Changes:
//
// 06/03/2011: Fixed bug in the initialization.
// 27/12/2009: Bug Fixed in Initilization process.
// 24/12/2008: Bug in Read procedure. In One irq I must read all the packets in the internal buffer
//             of ne2000. It is a circular buffer.Some problems if Buffer Overflow happens .
// 24/12/2007: Bug in size of Packets was solved.
// 10/11/2007: Rewritten the ISR
// 10/07/2007: Some bugs have been fixed.
// 17/06/2007: First Version by Matias Vara.
//
// Copyright (c) 2003-2011 Matias Vara <matiasvara@yahoo.com>
// All Rights Reserved
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

unit ne2000;

interface


{$I ..\Toro.inc}
{//$DEFINE DebugNE2000}

uses Arch, Console, Debug, Filesystem, Network, Process, Memory;


implementation

type
  PNe2000interface = ^TNe2000interface;
  TNe2000interface = record
    Driverinterface: TNetworkInterface;
    irq: LongInt;
    iobase: LongInt;
    NextPacket: LongInt;
  end;

const
  // Max Size of Packet in bytes
  MAX_PACKET_SIZE = 1500;

  COMMAND = 0;
  PAGESTART = 1;
  PAGESTOP = 2;
  BOUNDARY = 3;
  TRANSMITSTATUS =4;
  TRANSMITPAGE =4;
  TRANSMITBYTECOUNT0 =5;
  NCR =5;
  TRANSMITBYTECOUNT1 =6;
  INTERRUPTSTATUS =7;
  CURRENT=7;
  REMOTESTARTADDRESS0=8;
  CRDMA0=8;
  REMOTESTARTADDRESS1=9;
  CRDMA1=9;
  REMOTEBYTECOUNT0=10;
  REMOTEBYTECOUNT1=11;
  RECEIVESTATUS=12;
  RECEIVECONFIGURATION=12;
  TRANSMITCONFIGURATION=13;
  FAE_TALLY=13;
  DATACONFIGURATION=14;
  CRC_TALLY=14;
  INTERRUPTMASK=15;
  MISS_PKT_TALLY=15;
  IOPORT=16;

  dcr= $58;
  NE_RESET=$1f;
  NE_DATA=$10;
  TRANSMITBUFFER=$40;
  PSTART=$46;
  PSTOP=$80;

  // Some Ethernet commands
  E8390_START =2;
  E8390_TRANS =4;
  E8390_RREAD =8;
  E8390_RWRITE =$10;
  E8390_NODMA=$20;
  //E8390_PAGE0=0;

var
  ne2000card: TNe2000interface; // Support currently 1 ethernet card

// The card starts to work
procedure ne2000Start(Net: PNetworkInterface);
begin
  // initialize network driver
end;



procedure WritePort(Data: byte; Port: Word);
begin
asm
 nop
 nop
 nop
 nop
 nop
 nop
 nop
 nop
 nop
end;
Write_Portb(Data,Port);
asm
 nop
 nop
 nop
 nop
 nop
 nop
 nop
 nop
 nop
end;
end;


function ReadPort(Port: Word):byte;
begin
asm
 nop
 nop
 nop
 nop
 nop
 nop
 nop
 nop
 nop
end;
ReadPort:=Read_Portb(Port);
asm
 nop
 nop
 nop
 nop
 nop
 nop
 nop
 nop
 nop
end;
end;





// The card stop to work
procedure ne2000Stop(Net: PNetworkInterface);
begin
end;

type
  TByteArray = array[0..0] of Byte;
  PByteArray = ^TByteArray;

// Internal Job of NetworkSend
procedure DoSendPacket(Net: PNetworkInterface);
var
  Size, I: LongInt;
  Data: PByteArray;
  pkt: PPacket;
begin
// The first packet is sent
pkt:= net.OutgoingPackets;
Size:= pkt.size;
WritePort(Size and $ff, ne2000card.iobase+REMOTEBYTECOUNT0);
WritePort(Size shr 8, ne2000card.iobase+REMOTEBYTECOUNT1);
WritePort(0, ne2000card.iobase+REMOTESTARTADDRESS0);
WritePort(TRANSMITBUFFER, ne2000card.iobase+REMOTESTARTADDRESS1);
WritePort(E8390_RWRITE or E8390_START, ne2000card.iobase+COMMAND);
Data := pkt.Data;
for I := 0 to (Size-1) do
 WritePort(Data^[I], ne2000card.iobase+NE_DATA);
WritePort(TRANSMITBUFFER,ne2000card.iobase+TRANSMITPAGE);
WritePort(size, ne2000card.iobase+TRANSMITBYTECOUNT0);
WritePort(size shr 8 ,ne2000card.iobase+TRANSMITBYTECOUNT1);
WritePort(E8390_NODMA or E8390_TRANS or E8390_START, ne2000card.iobase+COMMAND);
end;

//
// Send a packet
//
procedure ne2000Send(net: PNetworkInterface;Packet: PPacket);
var
 PacketQueue: PPacket;
begin
// I need protection from Local IRQ
DisabledINT;
// Queue the packet
PacketQueue := Net.OutgoingPackets;
if PacketQueue = nil then
begin
 // I have got to enque it
 net.OutgoingPackets := Packet;
 // Send Directly
 DoSendPacket(net);
end
else begin
// It is a FIFO queue
  while PacketQueue.next <> nil do
   PacketQueue:=PacketQueue.next;
  PacketQueue.next :=Packet;
end;
EnabledINT;
end;


// Configure the card.
procedure InitNe2000(net: PNe2000interface);
var
 i:LongInt;
 buffer: array[0..31] of byte;
begin
// Reset driver
WritePort(ReadPort(net.iobase+NE_RESET), net.iobase+NE_RESET);
while ReadPort(net.iobase+INTERRUPTSTATUS) and $80 = 0 do
begin
 asm
  nop;
  nop;
  nop;
 end;
 end;
WritePort($ff,net.iobase+INTERRUPTSTATUS);
WritePort($21,net.iobase+COMMAND);
WritePort(dcr,net.iobase+DATACONFIGURATION);
WritePort($20,net.iobase+REMOTEBYTECOUNT0);
WritePort(0,net.iobase+REMOTEBYTECOUNT1);
WritePort(0,net.iobase+REMOTESTARTADDRESS0);
WritePort(0,net.iobase+REMOTESTARTADDRESS1);
WritePort(E8390_RREAD or E8390_START,net.iobase+COMMAND);
WritePort($e,net.iobase+RECEIVECONFIGURATION);
WritePort(4,net.iobase+TRANSMITCONFIGURATION);
 // Read EEPROM
  for i:=0 to 31 do
  begin
   buffer[i]:= ReadPort(net.iobase+IOPORT);
  end;
WritePort($40,net.iobase+TRANSMITPAGE);
WritePort($46,net.iobase+PAGESTART);
WritePort($46,net.iobase+BOUNDARY);
WritePort($60,net.iobase+PAGESTOP);
// Enable IRQ
WritePort($1f,net.iobase+INTERRUPTMASK);
WritePort($61,net.iobase+COMMAND);
// Program the Ethernet Address
WritePort($61,net.iobase+COMMAND);
WritePort(buffer[0],net.iobase+COMMAND + $1);
WritePort(buffer[2],net.iobase+COMMAND + $2);
WritePort(buffer[4],net.iobase+COMMAND + $3);
WritePort(buffer[6],net.iobase+COMMAND + $4);
WritePort(buffer[8],net.iobase+COMMAND + $5);
WritePort(buffer[10],net.iobase+COMMAND + $6);
// Program multicast address
WritePort($ff,net.iobase+COMMAND + $8);
WritePort($ff,net.iobase+COMMAND + $9);
WritePort($ff,net.iobase+COMMAND + $a);
WritePort($ff,net.iobase+COMMAND + $b);
WritePort($ff,net.iobase+COMMAND + $c);
WritePort($ff,net.iobase+COMMAND + $d);
WritePort($ff,net.iobase+COMMAND + $e);
WritePort($ff,net.iobase+COMMAND + $f);
// save Ethernet Number
for i:= 0 to 5 do
 net.DriverInterface.Hardaddress[i] := buffer[i*2];
WritePort(dcr,net.iobase+DATACONFIGURATION);
net.NextPacket := PSTART + 1;
WritePort(net.NextPacket, net.iobase+CURRENT);
// Ne2000 Start!
WritePort($22, net.iobase+COMMAND);
WritePort(0, net.iobase+TRANSMITCONFIGURATION);
WritePort($0C,net.iobase+RECEIVECONFIGURATION);
end;

// Read a packet from net card and enque it to Outgoing Packet list
procedure ReadPacket(Net: PNe2000interface);
var
  Curr: Byte;
  Data: PByteArray;
  rsr, Next, Count, Len: LongInt;
  Packet: PPacket;
begin
  // curr has the last packet in ne2000 internal buffer
  WritePort(E8390_START or E8390_NODMA or $40 ,net.iobase+COMMAND);
  curr := ReadPort(net.iobase+CURRENT);
  WritePort(E8390_START or E8390_NODMA ,net.iobase+COMMAND);
  // we must read all the packet in the buffer
  while curr <> net.NextPacket do
  begin
    WritePort(4,net.iobase+REMOTEBYTECOUNT0);
    WritePort(0,net.iobase+REMOTEBYTECOUNT1);
    WritePort(0,net.iobase+REMOTESTARTADDRESS0);
    WritePort(net.NextPacket, net.iobase+REMOTESTARTADDRESS1);
    WritePort(E8390_RREAD or E8390_START,net.iobase+COMMAND);
    rsr:= ReadPort(net.iobase+NE_DATA);
    next:= ReadPort(net.iobase+NE_DATA);
    len:= ReadPort(net.iobase+NE_DATA);
    len:= len + ReadPort(net.iobase+NE_DATA) shl 8;
    WritePort($40,net.iobase+INTERRUPTSTATUS);
    if (rsr and 31 = 1) and (next >=PSTART) and (next <= PSTOP) and (len <= 1532) then
    begin
      // Alloc memory for new packet
      Packet :=ToroGetMem(len+SizeOf(TPacket));
      Packet.data:= pointer(Packet + SizeOf(TPacket));
      Packet.size:= len;
      Data := Packet.data;
      WritePort(len, net.iobase+REMOTEBYTECOUNT0);
      WritePort(len shr 8, net.iobase+REMOTEBYTECOUNT1);
      WritePort(4, net.iobase+REMOTESTARTADDRESS0);
      WritePort(net.NextPacket, net.iobase+REMOTESTARTADDRESS1);
      WritePort(E8390_RREAD or E8390_START, net.iobase+COMMAND);
      // read the packet
      for Count:= 0 to len-1 do
        Data^[count] := ReadPort(net.iobase+NE_DATA);
      WritePort($40, net.iobase+INTERRUPTSTATUS);
      if next = PSTOP then
        net.NextPacket := PSTART
      else
        Net.NextPacket := next;
      EnqueueIncomingPacket(Packet);
    end;
    if net.NextPacket = PSTART then
      WritePort(PSTOP-1, net.iobase+BOUNDARY)
    else
      WritePort(net.NextPacket-1, net.iobase+BOUNDARY);
    // getting the position on the internal buffer
    WritePort(E8390_START or E8390_NODMA or $40 ,net.iobase+COMMAND);
    curr := ReadPort(net.iobase+CURRENT);
    WritePort(E8390_START or E8390_NODMA ,net.iobase+COMMAND);
  end;
end;

// Kernel raised some error -> Resend the last packet
procedure ne2000Reset(Net: PNetWorkInterface);
begin
  DisabledInt;
  DoSendPacket(Net);
  EnabledInt;
end;

// Ne2000 Irq Handler
procedure Ne2000Handler;
var
  Packet: PPacket;
  Status: LongInt;
begin
  Status := ReadPort(ne2000card.iobase + INTERRUPTSTATUS);
  if Status and 1 <> 0 then
  begin
    WritePort(Status,ne2000card.iobase + INTERRUPTSTATUS);
    ReadPacket(@ne2000card); // Transfer the packet to Packet Cache
    {$IFDEF DebugNe2000} DebugTrace('Ne2000IrqHandle: Packet readed', 0, 0, 0); {$ENDIF}
  end else if Status and $A <> 0 then
  begin
    WritePort(Status, ne2000card.iobase + INTERRUPTSTATUS);
    Packet := DequeueOutgoingPacket; // Inform Kernel Last packet has been sent, and fetch the next packet to send
    // We have got to send more packet ?
    if Packet <> nil then
      DoSendPacket(@ne2000card.DriverInterface);
    {$IFDEF DebugNe2000} DebugTrace('Ne2000IrqHandle: Packet Transmited', 0, 0, 0); {$ENDIF}
  end;
  eoi;
end;

// capture ne2000 irq and jump to ne2000Handler
// interruptions are disabled in the handler
procedure ne2000irqhandler; [nostackframe]; assembler;
asm
 // save registers
 push rbp
 push rax
 push rbx
 push rcx
 push rdx
 push rdi
 push rsi
 push r8
 push r9
 push r13
 push r14
 // protect the stack
 mov r15 , rsp
 mov rbp , r15
 sub r15 , 32
 mov  rsp , r15
 xor rcx , rcx
 // call handler
 Call ne2000handler
 mov rsp , rbp
 // restore the registers
 pop r14
 pop r13
 pop r9
 pop r8
 pop rsi
 pop rdi
 pop rdx
 pop rcx
 pop rbx
 pop rax
 pop rbp
 db $48
 db $cf
end;

// Look for ne2000 card in PCI bus and register it.
// Currently support for one NIC
procedure PCICardInit;
var
  Net: PNetworkInterface;
  PCIcard: PBusDevInfo;
begin
  PCIcard:= PCIDevices;
  while PCIcard <> nil do
  begin
    // looking for ethernet network card
    if (PCIcard.mainclass = $02) and (PCIcard.subclass = $00) then
    begin
      // looking for ne2000 card
      if (PCIcard.vendor = $10ec) and (PCIcard.device = $8029) then
      begin
        ne2000card.irq:=PCIcard.irq;
        ne2000card.iobase:=PCIcard.io[0];
        Net := @ne2000card.Driverinterface;
        Net.Name:= 'ne2000';
        Net.MaxPacketSize:= MAX_PACKET_SIZE;
        Net.start:= @ne2000Start;
        Net.send:= @ne2000Send;
        Net.stop:= @ne2000Stop;
        Net.Reset:= @ne2000Reset;
        Net.TimeStamp := 0;
        WriteConsole('ne2000 network card: /Vdetected/n on PCI bus',[]);
        InitNe2000(@ne2000card);
        Irq_On(ne2000card.irq);
        CaptureInt(32+ne2000card.irq, @ne2000irqhandler);
        RegisterNetworkInterface(Net);
        WriteConsole(', MAC:/V%d:%d:%d:%d:%d:%d/n\n', [Net.Hardaddress[0], Net.Hardaddress[1],
        Net.Hardaddress[2], Net.Hardaddress[3], Net.Hardaddress[4], Net.Hardaddress[5]]);
        Exit; // Support only 1 NIC in this version
        end;
      end;
    PCIcard := PCIcard.next;
    end;
end;


initialization
  PCICardInit;
  
end.