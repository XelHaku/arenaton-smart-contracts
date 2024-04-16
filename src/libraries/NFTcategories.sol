// SPDX-License-Identifier: LicenseRef-Proprietary

pragma solidity ^0.8.9;

// import './AStructs.sol';

library NFTcategories {
    // Define an enum for clarity in code. This makes the code more readable and avoids magic numbers.
    // Categories for Earnings
    uint8 public constant Soccer = 1;
    uint8 public constant Tennis = 2;
    uint8 public constant Basketball = 3;
    uint8 public constant Hockey = 4;
    uint8 public constant AmericanFootball = 5;
    uint8 public constant Baseball = 6;
    uint8 public constant Handball = 7;
    uint8 public constant RugbyUnion = 8;
    uint8 public constant Floorball = 9;
    uint8 public constant Bandy = 10;
    uint8 public constant Futsal = 11;
    uint8 public constant Volleyball = 12;
    uint8 public constant Cricket = 13;
    uint8 public constant Darts = 14;
    uint8 public constant Snooker = 15;
    uint8 public constant Boxing = 16;
    uint8 public constant BeachVolleyball = 17;
    uint8 public constant AussieRules = 18;
    uint8 public constant RugbyLeague = 19;
    uint8 public constant Badminton = 21;
    uint8 public constant WaterPolo = 22;
    uint8 public constant Golf = 23;
    uint8 public constant FieldHockey = 24;
    uint8 public constant TableTennis = 25;
    uint8 public constant BeachSoccer = 26;
    uint8 public constant MMA = 28;
    uint8 public constant Netball = 29;
    uint8 public constant Pesapallo = 30;
    uint8 public constant Esports = 36;
    uint8 public constant Kabaddi = 42;

    uint8 public constant TreasureChest = 90;
    uint8 public constant AtonTicket = 91;
    uint8 public constant Pixel = 93;
    uint8 public constant Atovix = 94;
    uint8 public constant VUNDrocket = 95;

    function getRegularCategoryIndex(uint i) internal pure returns (uint8) {
        uint8[32] memory categoryArray = [
            Soccer, // Socc er
            Tennis,
            Basketball,
            Hockey,
            AmericanFootball,
            Baseball,
            Handball,
            RugbyUnion,
            Floorball,
            Bandy,
            Futsal,
            Volleyball,
            Cricket,
            Darts,
            Snooker,
            Boxing,
            BeachVolleyball,
            AussieRules,
            RugbyLeague,
            Badminton,
            WaterPolo,
            Golf,
            FieldHockey,
            TableTennis,
            BeachSoccer,
            MMA,
            Netball,
            Pesapallo,
            Esports,
            Kabaddi, // Kabaddi
            VUNDrocket, // VUND Rocket
            TreasureChest // TreasureChest
        ];
        return categoryArray[i];
    }

    function getChestCategoryIndex(uint i) internal pure returns (uint8) {
        uint8[4] memory categoryArray = [
            AtonTicket, // Socc er
            Pixel, // VUND Rocket
            Atovix, //ART
            VUNDrocket
        ];
        return categoryArray[i];
    }

    function getAllCategoryIndex() internal pure returns (uint16[35] memory categoryArray) {
        return [
            Soccer,
            Tennis,
            Basketball,
            Hockey,
            AmericanFootball,
            Baseball,
            Handball,
            RugbyUnion,
            Floorball,
            Bandy,
            Futsal,
            Volleyball,
            Cricket,
            Darts,
            Snooker,
            Boxing,
            BeachVolleyball,
            AussieRules,
            RugbyLeague,
            Badminton,
            WaterPolo,
            Golf,
            FieldHockey,
            TableTennis,
            BeachSoccer,
            MMA,
            Netball,
            Pesapallo,
            Esports,
            uint16(Kabaddi), // Kabaddi
            uint16(TreasureChest), // TreasureChest
            uint16(AtonTicket), // Socc er
            uint16(Pixel), // VUND Rocket
            uint16(Atovix), //ART
            uint16(VUNDrocket)
        ];
    }
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
