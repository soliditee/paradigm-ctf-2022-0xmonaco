// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./Car.sol";
import "../utils/SignedWadMath.sol";

contract SmartCar04 is Car {
    /*//////////////////////////////////////////////////////////////
                            PRICING CONSTANTS
    //////////////////////////////////////////////////////////////*/

    int256 internal constant SHELL_TARGET_PRICE = 200e18;
    int256 internal constant SHELL_PER_TURN_DECREASE = 0.33e18;
    int256 internal constant SHELL_SELL_PER_TURN = 0.2e18;

    int256 internal constant ACCELERATE_TARGET_PRICE = 10e18;
    int256 internal constant ACCELERATE_PER_TURN_DECREASE = 0.33e18;
    int256 internal constant ACCELERATE_SELL_PER_TURN = 2e18;

    constructor(Monaco _monaco) Car(_monaco) {}

    function takeYourTurn(Monaco.CarData[] calldata allCars, uint256 ourCarIndex) external override {
        Monaco.CarData memory ourCar = allCars[ourCarIndex];
        uint256 FINISH_DISTANCE = 1000;
        uint16 currentTurn = monaco.turns();
        uint256 accSold = monaco.getActionsSold(Monaco.ActionType.ACCELERATE);
        // uint256 shellSold = monaco.getActionsSold(Monaco.ActionType.SHELL);
        uint256 accToBuy;
        uint256 defaultMaxBuy = 10;
        uint256 shellCostLimit = 400;

        // uint32 originalBalance = ourCar.balance;

        // Make sure we save some coins for the last miles
        if (ourCar.y > 0 && allCars[0].y < FINISH_DISTANCE - 40) {
            ourCar.balance -= 200;
        }

        // Make sure we save some coins for the last miles
        if (ourCar.y > 0 && allCars[0].y < FINISH_DISTANCE - 100) {
            ourCar.balance -= 500;
        }

        // Make sure we save some coins for the last miles, unless we're in 3rd place
        if (ourCar.y > 0 && ourCarIndex < 2 && allCars[0].y < FINISH_DISTANCE - 300) {
            ourCar.balance -= 1600;
        }

        if (ourCar.speed == 1) {
            // ourCar.balance = originalBalance; // Don't restore to original balance here because it could be costly to gain speed after getting shelled
            defaultMaxBuy = 5;
        }

        // If this is our first turn, accelerate until the price is high enough
        if (ourCar.y == 0) {
            defaultMaxBuy = 8;
            accToBuy = findAccAmountToBuy(400, currentTurn, accSold, ourCar.balance, defaultMaxBuy);
            if (accToBuy == 0 && currentTurn >= 20) {
                // If we haven't moved after several turns, increase the min price to make sure we can move
                accToBuy = findAccAmountToBuy(4000, currentTurn, accSold, ourCar.balance, defaultMaxBuy);
            }
            if (accToBuy > 0) {
                ourCar.balance -= uint24(monaco.buyAcceleration(accToBuy));
            }
            return;
        }

        // If we're in 1st place
        if (ourCarIndex == 0) {
            // Focus on Acceleration
            uint256 minPriceForAcc = 200;
            // If the car behind us is not faster than us, we don't really need to accelerate
            if (allCars[1].speed <= ourCar.speed) {
                minPriceForAcc = 50;
            }
            accToBuy = findAccAmountToBuy(minPriceForAcc, currentTurn, accSold, ourCar.balance, defaultMaxBuy);
            if (accToBuy > 0) {
                ourCar.balance -= uint24(monaco.buyAcceleration(accToBuy));
            }
            return;
        }
        bool isShellBought = false;

        // If we're in 2nd place and there's one car behind us
        if (ourCarIndex == 1 && allCars[ourCarIndex + 1].y < ourCar.y) {
            uint256 shellCost = monaco.getShellCost(1);

            if (allCars[0].y > FINISH_DISTANCE - 50) {
                shellCostLimit = 5000;
            }
            // If we're closed to finish or if the 1st car is too far ahead, focus on Shell
            if (allCars[0].y > FINISH_DISTANCE - 200 || (allCars[0].y - ourCar.y > 60)) {
                if (ourCar.balance > shellCost && shellCost < shellCostLimit) {
                    ourCar.balance -= uint24(monaco.buyShell(1));
                    isShellBought = true;
                }
                accToBuy = findAccAmountToBuy(600, currentTurn, accSold, ourCar.balance, defaultMaxBuy);
                if (accToBuy > 0) {
                    ourCar.balance -= uint24(monaco.buyAcceleration(accToBuy));
                }
            } else {
                // If we're far from finish, focus on Acceleration
                accToBuy = findAccAmountToBuy(200, currentTurn, accSold, ourCar.balance, defaultMaxBuy);
                if (accToBuy > 0) {
                    ourCar.balance -= uint24(monaco.buyAcceleration(accToBuy));
                }
            }
            uint32 balanceGap = ourCar.balance > allCars[0].balance ? ourCar.balance - allCars[0].balance : 0;
            if (!isShellBought && ourCar.balance > shellCost && (shellCost < 200 || balanceGap >= shellCost)) {
                // If Shell is cheap, just buy it
                ourCar.balance -= uint24(monaco.buyShell(1));
                isShellBought = true;
            }
            return;
        }

        // If we're in 3rd place, focus on Acceleration
        if (ourCarIndex == 2) {
            uint256 shellCost = monaco.getShellCost(1);
            uint256 minPrice = 200;
            defaultMaxBuy = 14;

            if (allCars[0].y < FINISH_DISTANCE - 200) {
                minPrice = 400;
            } else if (allCars[0].y < FINISH_DISTANCE - 60) {
                minPrice = 3000;
                shellCostLimit = 3000;
            }

            if (
                !isShellBought &&
                allCars[ourCarIndex - 1].speed > ourCar.speed &&
                ourCar.balance > shellCost &&
                shellCost < shellCostLimit
            ) {
                // If Shell is cheap, just buy it
                ourCar.balance -= uint24(monaco.buyShell(1));
                isShellBought = true;
            }

            accToBuy = findAccAmountToBuy(minPrice, currentTurn, accSold, ourCar.balance, 30);
            if (accToBuy > 0) {
                ourCar.balance -= uint24(monaco.buyAcceleration(accToBuy));
            }
        }
    }

    function findAccAmountToBuy(
        uint256 minPriceAfterBuying,
        uint16 currentTurn,
        uint256 accelerateSold,
        uint32 ourBalance,
        uint256 maxBuy
    ) internal pure returns (uint256 accAmountToBuy) {
        uint256 price;
        uint256 sum;
        unchecked {
            for (uint256 i = 0; i < maxBuy; i++) {
                price = computeActionPrice(
                    ACCELERATE_TARGET_PRICE,
                    ACCELERATE_PER_TURN_DECREASE,
                    currentTurn,
                    accelerateSold + i,
                    ACCELERATE_SELL_PER_TURN
                );
                sum += price;
                if (sum > ourBalance) {
                    if (i > 0) {
                        accAmountToBuy = i - 1;
                        break;
                    }
                }
                if (price >= minPriceAfterBuying) {
                    accAmountToBuy = i;
                    break;
                }
                if (i == maxBuy - 1) {
                    // Last loop
                    accAmountToBuy = maxBuy;
                }
            }
        }
    }

    function computeActionPrice(
        int256 targetPrice,
        int256 perTurnPriceDecrease,
        uint256 turnsSinceStart,
        uint256 sold,
        int256 sellPerTurnWad
    ) internal pure returns (uint256) {
        // Theoretically calling toWadUnsafe with turnsSinceStart and sold can overflow without
        // detection, but under any reasonable circumstance they will never be large enough.
        // Use sold + 1 as we need the number of the tokens that will be sold (inclusive).
        // Use turnsSinceStart - 1 since turns start at 1 but here the first turn should be 0.
        unchecked {
            return
                uint256(
                    wadMul(
                        targetPrice,
                        wadExp(
                            unsafeWadMul(
                                wadLn(1e18 - perTurnPriceDecrease),
                                toWadUnsafe(turnsSinceStart - 1) - (wadDiv(toWadUnsafe(sold + 1), sellPerTurnWad))
                            )
                        )
                    )
                ) / 1e18;
        }
    }
}
