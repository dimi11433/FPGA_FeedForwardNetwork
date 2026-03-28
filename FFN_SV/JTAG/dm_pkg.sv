package dm;

  // -------------------------------------------------------
  // Line 1: "package dm;" — starts the package block.
  // Everything inside here belongs to the "dm" namespace.
  // That's why you see dm::dmi_req_t — it's like saying
  // "grab dmi_req_t from the dm package".
  // -------------------------------------------------------


  // -------------------------------------------------------
  // DTM OPERATION CODES
  // These are the values that go in the "op" field of a
  // DMI request. The host sends one of these to say
  // "I want to read" or "I want to write".
  // typedef enum = define a named set of constants.
  // logic [1:0] = each constant is 2 bits wide.
  // -------------------------------------------------------
  typedef enum logic [1:0] {
    DTM_NOP   = 2'h0,   // do nothing
    DTM_READ  = 2'h1,   // host wants to read from an address
    DTM_WRITE = 2'h2    // host wants to write to an address
  } dtm_op_e;


  // -------------------------------------------------------
  // DMI RESPONSE CODES
  // After your design handles a read/write, it sends back
  // one of these codes to say "it worked" or "it failed".
  // localparam = a constant value (not a type, just a value).
  // -------------------------------------------------------
  localparam logic [1:0] DTM_SUCCESS = 2'h0;  // operation succeeded
  localparam logic [1:0] DTM_ERR     = 2'h2;  // operation failed
  localparam logic [1:0] DTM_BUSY    = 2'h3;  // still busy, try again


  // -------------------------------------------------------
  // DMI REQUEST STRUCT
  // This is the "envelope" the host sends to your design.
  // typedef struct packed = define a named group of signals
  //   that are stored back-to-back in memory (packed = no gaps).
  // Fields:
  //   addr — which debug register to access (7 bits)
  //   data — value to write (32 bits, ignored on reads)
  //   op   — what to do: read, write, or noop (2 bits)
  // -------------------------------------------------------
  typedef struct packed {
    logic [6:0]  addr;   // 7-bit address — matches abits=7 in DTMCS
    logic [31:0] data;   // 32-bit data payload
    dtm_op_e     op;     // 2-bit operation (uses the enum above)
  } dmi_req_t;


  // -------------------------------------------------------
  // DMI RESPONSE STRUCT
  // This is what your design sends back to the host.
  // Fields:
  //   data — the value read from the addressed register
  //   resp — success or error code (uses localparam above)
  // -------------------------------------------------------
  typedef struct packed {
    logic [31:0] data;   // 32-bit read data
    logic [1:0]  resp;   // 2-bit response code
  } dmi_resp_t;


  // -------------------------------------------------------
  // DTMCS REGISTER STRUCT
  // This maps the 32-bit DTMCS register field by field.
  // In a packed struct, fields are laid out MSB first.
  // So zero1 occupies bits [31:18], dmihardreset is bit [17], etc.
  //
  // Bit layout (must add to exactly 32 bits):
  //   [31:18] zero1        = 14 bits  (reserved, always 0)
  //   [17]    dmihardreset =  1 bit   (write 1 = hard reset DMI)
  //   [16]    dmireset     =  1 bit   (write 1 = clear error flag)
  //   [15]    zero0        =  1 bit   (reserved, always 0)
  //   [14:12] idle         =  3 bits  (idle cycles needed)
  //   [11:10] dmistat      =  2 bits  (current error status)
  //   [9:4]   abits        =  6 bits  (DMI address width = 7)
  //   [3:0]   version      =  4 bits  (debug spec version = 1)
  //                          --------
  //                          32 bits total
  // -------------------------------------------------------
  typedef struct packed {
    logic [13:0] zero1;         // [31:18] reserved
    logic        dmihardreset;  // [17]    hard reset
    logic        dmireset;      // [16]    soft reset
    logic        zero0;         // [15]    reserved
    logic [2:0]  idle;          // [14:12] idle cycles
    logic [1:0]  dmistat;       // [11:10] error status
    logic [5:0]  abits;         // [9:4]   address bits
    logic [3:0]  version;       // [3:0]   spec version
  } dtmcs_t;


endpackage : dm
// "endpackage : dm" closes the package block.
// The ": dm" label is optional but good practice —
// it makes it clear what you're closing.
