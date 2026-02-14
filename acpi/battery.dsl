
DefinitionBlock ("battery.aml", "SSDT", 2, "FCKGW", "BATT", 0x00000001)
{
    Scope (\_SB)
    {
        Device (BAT0)
        {
            Name (_HID, EisaId ("PNP0C0A"))
            Name (_UID, 0x00)
            Name (_STA, 0x1F)

            Name (_BIF, Package (0x0D)
            {
                0x01,       // Power Unit (mWh)
                0xFFFFFFFF, // Design Capacity
                0xFFFFFFFF, // Last Full Charge Capacity
                0x01,       // Battery Technology (rechargeable)
                0x2A30,     // Design Voltage (10.8V)
                0x00,       // Design Capacity of Warning
                0x00,       // Design Capacity of Low
                0x01,       // Battery Capacity Granularity 1
                0x01,       // Battery Capacity Granularity 2
                "Virtual",  // Model Number
                "0000",     // Serial Number
                "LION",     // Battery Type
                "DragonForge" // OEM Information
            })

            Name (_BST, Package (0x04)
            {
                0x00,       // Battery State (not charging, not discharging)
                0x00,       // Battery Present Rate
                0x2710,     // Battery Remaining Capacity (10000 mWh)
                0x2A30      // Battery Present Voltage (10.8V)
            })

            Method (_PCL, 0, NotSerialized)
            {
                Return (\_SB)
            }
        }
    }
}
