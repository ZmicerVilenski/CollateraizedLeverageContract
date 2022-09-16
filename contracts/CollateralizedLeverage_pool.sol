// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CollateralizedLeverage_pool
 * This contract was developed from the very beginning, because I misunderstood the assignment.
 * It allows to lend to the collective pool and take any amount from the pool without being tied to a specific lender.
 * But for production, it still needs to be finalized.
 */
contract CollateralizedLeverage_pool is Ownable {
    uint256 public constant MONTH = 30 days;
    uint256 public constant EXCANGE_RATE = 2;
    uint256 public constant MONTH_RETURN_RATE = 5;
    uint256 public constant MONTH_INTEREST_RATE = 10;

    IERC20 private immutable tokenX;
    IERC20 private immutable tokenA;
    struct LoanData {
        uint256 amount;
        uint256 timestamp;
        uint256 reward;
    }
    struct Mortgage {
        uint256 amountX;
        uint256 amountA;
        uint128 startDate;
        uint128 duration;
    }
    mapping(address => LoanData) public pool;
    mapping(address => Mortgage[]) public loans;

    event AddedToPool(
        address indexed loaner,
        uint256 amount,
        uint256 timestamp
    );
    event WithdrawedFromPool(
        address indexed loaner,
        uint256 amount,
        uint256 reward
    );

    event CollateralLoanTaken(
        address indexed borrower,
        uint256 amountX,
        uint256 amountA,
        uint256 timestamp
    );

    event CollateralLoanReturned(
        address indexed borrower,
        uint256 amountX,
        uint256 paybackX,
        uint256 amountA,
        uint256 timestamp
    );

    event CollateralLoanRenewed(
        address indexed borrower,
        uint256 amountX,
        uint256 paybackX,
        uint256 amountA,
        uint256 timestamp
    );

    /**
     * @dev Creates a collateralized leverage contract.
     * @param _tokenX address of the IERC20 stable token.
     * @param _tokenA address of the IERC20 collateral token.
     */
    constructor(address _tokenX, address _tokenA) {
        tokenX = IERC20(_tokenX);
        tokenA = IERC20(_tokenA);
    }

    /**
     * @notice Safely cast an uint256 to an uint128
     * @param x convertible number
     */
    function u128(uint256 x) internal pure returns (uint128 y) {
        require(x <= type(uint128).max, "Cast overflow");
        y = uint128(x);
    }

    /**
     * @notice Adds stablecoins from the lender to the lending pool.
     * @param _amountTokenX amount of stable coins
     */
    function AddToPool(uint256 _amountTokenX) external {
        require(_amountTokenX > 0, "Too small loan");
        address loaner = msg.sender;
        LoanData memory loanData = pool[loaner];
        uint256 reward;
        if (pool[loaner].amount != 0) {
            reward = _calculatePoolReward(
                loanData.amount,
                block.timestamp - loanData.timestamp
            );
        }
        loanData.amount = loanData.amount + _amountTokenX;
        loanData.timestamp = block.timestamp;
        loanData.reward = reward;
        pool[loaner] = loanData;
        tokenX.transferFrom(loaner, address(this), _amountTokenX);
        emit AddedToPool(loaner, _amountTokenX, block.timestamp);
    }

    /**
     * @notice Returns stablecoins with rewards to the lender
     * @param _amountTokenX amount of stable coins
     */
    function withdrawFromPool(uint256 _amountTokenX) external {
        address loaner = msg.sender;
        LoanData memory loanData = pool[loaner];
        require(loanData.amount != 0, "Not loaner");
        require(loanData.amount >= _amountTokenX, "To big amount");
        uint256 reward = _calculatePoolReward(
            loanData.amount,
            block.timestamp - loanData.timestamp
        );
        require(
            tokenX.balanceOf(address(this)) >= _amountTokenX + reward,
            "Insufficient pool volume"
        );
        loanData.amount = loanData.amount - _amountTokenX;
        loanData.timestamp = block.timestamp;
        reward = reward + loanData.reward;
        loanData.reward = 0;
        pool[loaner] = loanData;
        uint256 finalAmount = _amountTokenX + reward;
        tokenX.transfer(loaner, finalAmount);
        emit WithdrawedFromPool(loaner, _amountTokenX, reward);
    }

    /**
     * @dev Calculate rewards to the lender. Based on retention period and interest rate.
     * @param _amount base sum of calculations
     * @param _duration of investment period
     */
    function _calculatePoolReward(uint256 _amount, uint256 _duration)
        internal
        pure
        returns (uint256 reward)
    {
        uint256 rewardPerMonth = (_amount * MONTH_RETURN_RATE) / 100;
        uint256 monthsNum = _duration / MONTH;
        for (uint256 i = 0; i <= monthsNum; i++) {
            reward += rewardPerMonth;
        }
    }

    /**
     * @notice Returns investment amount of a particular lender
     * @param _loaner address of the lender
     */
    function getPoolAmountForLoaner(address _loaner)
        external
        view
        returns (uint256)
    {
        return pool[_loaner].amount;
    }

    /**
     * @notice Returns reward amount of a particular lender
     * @param _loaner address of the lender
     */
    function getPoolRewardForLoaner(address _loaner)
        external
        view
        returns (uint256)
    {
        return
            _calculatePoolReward(
                pool[_loaner].amount,
                block.timestamp - pool[_loaner].timestamp
            );
    }

    /**
     * @notice Allows the borrower to borrow any ammount of stable tokens from the pool. Needed collateral.
     * @param _amountTokenA amount of collateral token
     * @param _duration of collateral period
     */
    function takeCollateralLoan(uint256 _amountTokenA, uint128 _duration)
        external
    {
        require(_duration >= MONTH, "Minimum lock period 1 month");
        address borrower = msg.sender;
        uint256 _amountTokenX = _amountTokenA / EXCANGE_RATE;
        require(
            tokenX.balanceOf(address(this)) >= _amountTokenX,
            "Insufficient pool volume"
        );
        loans[borrower].push(
            Mortgage(
                _amountTokenX,
                _amountTokenA,
                u128(block.timestamp),
                _duration
            )
        );
        tokenA.transferFrom(borrower, address(this), _amountTokenA);
        tokenX.transfer(borrower, _amountTokenX);
        emit CollateralLoanTaken(
            borrower,
            _amountTokenX,
            _amountTokenA,
            block.timestamp
        );
    }

    /**
     * @notice Repayment by the borrower of the loan taken and return of the collateral
     * @param _loanID  borrower loan ID
     */
    function returnCollateralLoan(uint256 _loanID) external {
        address borrower = msg.sender;
        require((_loanID < loans[borrower].length), "Incorrect Loan ID");
        Mortgage memory loan = loans[borrower][_loanID];
        require(
            block.timestamp <= loan.startDate + loan.duration,
            "Incomplete locking period"
        );
        uint256 payback = _calculateReturnsForBorrower(loan);
        tokenX.transferFrom(borrower, address(this), loan.amountX + payback);
        tokenA.transfer(borrower, loan.amountA);
        // Delete loan from array
        loans[borrower][_loanID] = loans[borrower][loans[borrower].length - 1];
        loans[borrower].pop();
        //
        emit CollateralLoanReturned(
            borrower,
            loan.amountX,
            payback,
            loan.amountA,
            block.timestamp
        );
    }

    /**
     * @dev in developing
     * @param _loanID  borrower loan ID
     */
    function returnCollateralLoanAheadOfSchedule(uint256 _loanID) external {
        // The same as returnCollateralLoan() but without controll of locktime and return with penalty (and payback).
        // Not implemented for simplicity
    }

    /**
     * @notice Calculate loan fee to the borrower. Based on retention period and loan fee rate.
     * @param _loanID borrower loan ID
     * @param _newDuration new duration of the loan
     */
    function renewCollateralLoan(uint256 _loanID, uint128 _newDuration)
        external
    {
        require(_newDuration >= MONTH, "Minimum lock period 1 month");
        address borrower = msg.sender;
        require((_loanID < loans[borrower].length), "Incorrect Loan ID");
        Mortgage memory loan = loans[borrower][_loanID];
        uint256 payback = _calculateReturnsForBorrower(loan);
        loan.startDate = u128(block.timestamp);
        loan.duration = _newDuration;
        loans[borrower][_loanID] = loan;
        tokenX.transferFrom(borrower, address(this), payback);
        emit CollateralLoanRenewed(
            borrower,
            loan.amountX,
            payback,
            loan.amountA,
            block.timestamp
        );
    }

    /**
     * @notice Calculate loan fee to the borrower. Based on retention period and loan fee rate.
     * @param _loan structure of loan
     */
    function _calculateReturnsForBorrower(Mortgage memory _loan)
        internal
        view
        returns (uint256 payback)
    {
        uint256 duration = block.timestamp - _loan.startDate;
        uint256 paybackPerMonth = (_loan.amountX * MONTH_INTEREST_RATE) / 100;
        uint256 monthsNum = duration / MONTH;
        for (uint256 i = 0; i <= monthsNum; i++) {
            payback += paybackPerMonth;
        }
    }

    // BONUS: Can we add a check that allows the lender to take the collateral before the end of the lock period in case the previous situation applies?
    // ANSWER: Yes
    /**
     * @notice Determines if the loan fee exceeded the collateral
     * @param _loanID borrower loan ID
     */
    function CollateralLowerThanInterest(uint256 _loanID)
        public
        view
        returns (bool)
    {
        address borrower = msg.sender;
        Mortgage memory loan = loans[borrower][_loanID];
        return _calculateReturnsForBorrower(loan) > loan.amountX;
    }

    // BONUS: Assuming that the exchange rate between token A and token X will be the same. What is the maximum period it is advised to issue a loan? I.E. Is there a moment where collateral will be lower than principal+interest?
    // ANSWER: With the condition that the interest is 10%, after 10 months the deposit will be less than collateral (10% * 10 = 100%)
}

// !!! I have a misunderstanding of this paragraph:
// Scenario 2 Borrower can’t pay back the loan
//    - Lender can decide to take collateral at any time
//
// If Lenders put funds into a pool, and borrowers take from the pool. This means that borrower is not related to the Lender.
// How then Lender can take collateral?
// Of course, possible to take collateral from the pool, but how to determine which Lender to give collateral to?
// And there is the problem of obtaining a list of overdue loans. I don't know how to solve this problem OnChain.
// If the borrower has overdue the loan and does not take any action, then it is not clear how to get data on his loan.
// It is possible to contain an array with active (unclosed credits), but if it is large, there may not be enough gas to search through it.
// In my opinion, the best solution for tracking overdue loans is the backend.
// Possible to parse the list of events from the frontend, but this can be a problem due to the size of the list.
