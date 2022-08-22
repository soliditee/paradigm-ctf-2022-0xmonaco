// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../src/Monaco.sol";
import "../src/cars/ExampleCar.sol";

import "../src/cars/SmartCar01.sol";
import "../src/cars/SmartCar02.sol";
import "../src/cars/SmartCar03.sol";
import "../src/cars/SmartCar04.sol";
import "../src/cars/SmartCar05.sol";

contract MonacoTest is Test {
    Monaco monaco;

    mapping(address => uint256) private carAddressToRegisterOrder;

    function setUp() public {
        monaco = new Monaco();
    }

    function testGames() public {
        // ExampleCar w1 = new ExampleCar(monaco);
        SmartCar05 w1 = new SmartCar05(monaco);

        // ExampleCar w2 = new ExampleCar(monaco);
        SmartCar02 w2 = new SmartCar02(monaco);

        ExampleCar w3 = new ExampleCar(monaco);

        monaco.register(w1);
        monaco.register(w2);
        monaco.register(w3);

        carAddressToRegisterOrder[address(w1)] = 1;
        carAddressToRegisterOrder[address(w2)] = 2;
        carAddressToRegisterOrder[address(w3)] = 3;

        // You can throw these CSV logs into Excel/Sheets/Numbers or a similar tool to visualize a race!
        vm.writeFile(
            string.concat("logs/", vm.toString(carAddressToRegisterOrder[address(w1)]), ".csv"),
            "turns,balance,speed,y\n"
        );
        vm.writeFile(
            string.concat("logs/", vm.toString(carAddressToRegisterOrder[address(w2)]), ".csv"),
            "turns,balance,speed,y\n"
        );
        vm.writeFile(
            string.concat("logs/", vm.toString(carAddressToRegisterOrder[address(w3)]), ".csv"),
            "turns,balance,speed,y\n"
        );
        vm.writeFile("logs/prices.csv", "turns,accelerateCost,shellCost\n");
        vm.writeFile("logs/sold.csv", "turns,acceleratesBought,shellsBought\n");
        vm.writeFile("logs/sold-prices.csv", "turns,acceleratesBought,accelerateCost,shellsBought,shellCost\n");

        while (monaco.state() != Monaco.State.DONE) {
            monaco.play(1);

            emit log("");

            Monaco.CarData[] memory allCarData = monaco.getAllCarData();

            for (uint256 i = 0; i < allCarData.length; i++) {
                Monaco.CarData memory car = allCarData[i];

                emit log_address(address(car.car));
                emit log_named_uint("balance", car.balance);
                emit log_named_uint("speed", car.speed);
                emit log_named_uint("y", car.y);

                vm.writeLine(
                    string.concat("logs/", vm.toString(carAddressToRegisterOrder[address(car.car)]), ".csv"),
                    string.concat(
                        vm.toString(uint256(monaco.turns())),
                        ",",
                        vm.toString(car.balance),
                        ",",
                        vm.toString(car.speed),
                        ",",
                        vm.toString(car.y)
                    )
                );

                if (i == 0) {
                    vm.writeLine(
                        "logs/prices.csv",
                        string.concat(
                            vm.toString(uint256(monaco.turns())),
                            ",",
                            vm.toString(monaco.getAccelerateCost(1)),
                            ",",
                            vm.toString(monaco.getShellCost(1))
                        )
                    );

                    vm.writeLine(
                        "logs/sold.csv",
                        string.concat(
                            vm.toString(uint256(monaco.turns())),
                            ",",
                            vm.toString(monaco.getActionsSold(Monaco.ActionType.ACCELERATE)),
                            ",",
                            vm.toString(monaco.getActionsSold(Monaco.ActionType.SHELL))
                        )
                    );

                    vm.writeLine(
                        "logs/sold-prices.csv",
                        string.concat(
                            vm.toString(uint256(monaco.turns())),
                            ",",
                            vm.toString(monaco.getActionsSold(Monaco.ActionType.ACCELERATE)),
                            ",",
                            vm.toString(monaco.getAccelerateCost(1)),
                            ",",
                            vm.toString(monaco.getActionsSold(Monaco.ActionType.SHELL)),
                            ",",
                            vm.toString(monaco.getShellCost(1))
                        )
                    );
                }
            }
        }

        emit log_named_uint("Number Of Turns", monaco.turns());
    }
}
