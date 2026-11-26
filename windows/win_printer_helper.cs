using System;
using System.IO;
using System.IO.Ports;
using System.Threading;
using System.Runtime.InteropServices;

public class PrinterHelper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public class DOCINFOA {
        [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
    }

    [DllImport("winspool.Drv", EntryPoint = "OpenPrinterA", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern bool OpenPrinter(string szPrinter, out IntPtr hPrinter, IntPtr pd);

    [DllImport("winspool.Drv", EntryPoint = "ClosePrinter", SetLastError = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterA", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, int level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);

    [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter", SetLastError = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartPagePrinter", SetLastError = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "EndPagePrinter", SetLastError = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "WritePrinter", SetLastError = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);

    public static int Main(string[] args) {
        if (args.Length < 2) {
            Console.WriteLine("Usage: win_printer_helper.exe <mode: spool|serial> <target> <filePath> [baudRate]");
            return 1;
        }

        string mode = args[0].ToLowerInvariant();
        string target = args[1];

        try {
            if (mode == "spool") {
                if (args.Length < 3) {
                    Console.WriteLine("ERROR: Missing filePath for spool mode.");
                    return 2;
                }
                string filePath = args[2];
                return PrintSpoolRaw(target, filePath);
            } else if (mode == "serial") {
                if (args.Length < 3) {
                    Console.WriteLine("ERROR: Missing filePath for serial mode.");
                    return 2;
                }
                string filePath = args[2];
                int baudRate = 9600;
                if (args.Length >= 4) {
                    int.TryParse(args[3], out baudRate);
                }
                if (baudRate <= 0) baudRate = 9600;
                return PrintSerial(target, filePath, baudRate);
            } else {
                Console.WriteLine("ERROR: Unknown mode " + mode);
                return 1;
            }
        } catch (Exception ex) {
            Console.WriteLine("EXCEPTION: " + ex.Message);
            return 99;
        }
    }

    static int PrintSpoolRaw(string printerName, string filePath) {
        if (!File.Exists(filePath)) {
            Console.WriteLine("ERROR: File not found: " + filePath);
            return 10;
        }

        byte[] bytes = File.ReadAllBytes(filePath);
        if (bytes.Length == 0) {
            Console.WriteLine("ERROR: File is empty.");
            return 11;
        }

        IntPtr pUnmanagedBytes = Marshal.AllocCoTaskMem(bytes.Length);
        Marshal.Copy(bytes, 0, pUnmanagedBytes, bytes.Length);

        IntPtr hPrinter;
        if (!OpenPrinter(printerName, out hPrinter, IntPtr.Zero)) {
            Marshal.FreeCoTaskMem(pUnmanagedBytes);
            int err = Marshal.GetLastWin32Error();
            Console.WriteLine("ERROR: OpenPrinter failed for " + printerName + " (Win32Error: " + err + ")");
            return 12;
        }

        DOCINFOA di = new DOCINFOA();
        di.pDocName = "Thermal Receipt";
        di.pDataType = "RAW";

        bool success = false;
        try {
            if (StartDocPrinter(hPrinter, 1, di)) {
                if (StartPagePrinter(hPrinter)) {
                    int dwWritten = 0;
                    success = WritePrinter(hPrinter, pUnmanagedBytes, bytes.Length, out dwWritten);
                    EndPagePrinter(hPrinter);
                }
                EndDocPrinter(hPrinter);
            }
        } finally {
            ClosePrinter(hPrinter);
            Marshal.FreeCoTaskMem(pUnmanagedBytes);
        }

        if (success) {
            Console.WriteLine("SUCCESS");
            return 0;
        } else {
            int err = Marshal.GetLastWin32Error();
            Console.WriteLine("ERROR: WritePrinter failed (Win32Error: " + err + ")");
            return 13;
        }
    }

    static int PrintSerial(string portName, string filePath, int baudRate) {
        if (!File.Exists(filePath)) {
            Console.WriteLine("ERROR: File not found: " + filePath);
            return 20;
        }

        byte[] bytes = File.ReadAllBytes(filePath);
        if (bytes.Length == 0) {
            Console.WriteLine("ERROR: File is empty.");
            return 21;
        }

        string cleanPort = portName.Replace(":", "").Replace(@"\\.\", "").Trim().ToUpperInvariant();

        using (SerialPort port = new SerialPort(cleanPort, baudRate, Parity.None, 8, StopBits.One)) {
            port.DtrEnable = true;
            port.RtsEnable = true;
            port.WriteTimeout = 3000;
            port.ReadTimeout = 2000;
            port.Handshake = Handshake.None;

            try {
                port.Open();
            } catch (Exception ex) {
                Console.WriteLine("ERROR: Failed to open port " + cleanPort + ": " + ex.Message);
                return 22;
            }

            try {
                port.Write(bytes, 0, bytes.Length);
                Thread.Sleep(200);
                Console.WriteLine("SUCCESS");
                return 0;
            } catch (Exception ex) {
                Console.WriteLine("ERROR: Failed to write to " + cleanPort + ": " + ex.Message);
                return 23;
            } finally {
                try { port.Close(); } catch { }
            }
        }
    }
}
