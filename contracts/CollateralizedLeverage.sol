// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CollateralizedLeverage
 */
contract CollateralizedLeverage is Ownable {
    uint80 public constant MONTH = 30 days;
    uint256 public constant EXCANGE_RATE = 2;
    uint256 public constant MONTH_REWARD_RATE = 5;
    uint256 public constant MONTH_PAYBACK_RATE = 10;
    uint256 public loanId;
    /**
     * @dev Loan structure. The order of the fields in the structure is determined by saving memory cells
     */
    struct Loan {
        address lender;
        address borrower;
        uint256 tokenX;
        uint256 tokenA;
        uint80 loanCreated;
        uint80 loanUsed;
        uint80 duration;
        bool clamed;
        bool finished;
    }
    mapping(uint256 => Loan) public loans;
    IERC20 private immutable tokenX;
    IERC20 private immutable tokenA;

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
     * @notice Adds stablecoins from the lender to the lending pool.
     * @param _amountX amount of stable coins
     * @param _duration duration in months of lending period
     */
    function AddToPool(uint256 _amountX, uint80 _duration) external {
        require(_duration > 0, "Minimum 1 month");
        require(_amountX > 0, "Very small contribution");

        address loaner = msg.sender;
        tokenX.transferFrom(loaner, address(this), _amountX);
        Loan memory loan = Loan({
            lender: loaner,
            tokenX: _amountX,
            duration: u80(block.timestamp) + (_duration * MONTH),
            loanCreated: u80(block.timestamp),
            borrower: address(0x0),
            loanUsed: 0,
            tokenA: 0,
            clamed: false,
            finished: false
        });
        loans[loanId] = loan;
        loanId++;

        emit AddedToPool(loaner, _amountX, block.timestamp);
    }

    /**
     * @notice Returns stablecoins with rewards to the lender
     * @param _id lending-pool loan ID
     */
    function WithdrawFromPool(uint256 _id) external {
        require(msg.sender == loans[_id].lender, "Not a lender");
        require(!loans[_id].finished, "Investments already taken");
        require(
            loans[_id].clamed ||
                block.timestamp > loans[_id].duration ||
                CollateralLowerThanInterest(_id),
            "Loan must be inactive or returned or exceeded the deposit"
        );

        uint256 reward = CalculateRewards(_id);
        loans[_id].finished = true;

        tokenX.transfer(msg.sender, loans[_id].tokenX + reward);

        emit WithdrawedFromPool(msg.sender, loans[_id].tokenX, reward);
    }

    /**
     * @notice Calculate rewards to the lender. Based on retention period and interest rate.
     * @param _id lending-pool loan ID
     */
    function CalculateRewards(uint256 _id)
        public
        view
        returns (uint256 amount)
    {
        uint256 rewardPerMonth = (loans[_id].tokenX * MONTH_REWARD_RATE) / 100;
        uint256 monthsNum = (block.timestamp - loans[_id].loanCreated) / MONTH;
        for (uint256 i = 0; i <= monthsNum; i++) {
            amount += rewardPerMonth;
        }
    }

    /**
     * @notice Allows the borrower to borrow a specific loan from the pool. Needed collateral.
     * @param _id lending-pool loan ID
     */
    function TakeCollateralLoan(uint256 _id) external {
        address borrower = msg.sender;
        require(
            borrower != loans[_id].lender,
            "Impossible to take your own loan"
        );
        require(loans[_id].loanUsed == 0, "Loan is using");

        uint256 amountA = loans[_id].tokenX * EXCANGE_RATE;
        loans[_id].borrower = borrower;
        loans[_id].tokenA = amountA;
        loans[_id].loanUsed = u80(block.timestamp);

        tokenA.transferFrom(borrower, address(this), amountA);
        tokenX.transfer(borrower, loans[_id].tokenX);

        emit CollateralLoanTaken(
            borrower,
            loans[_id].tokenX,
            amountA,
            block.timestamp
        );
    }

    /**
     * @notice Repayment by the borrower of the loan taken and return of the collateral
     * @param _id lending-pool loan ID
     */
    function Payback(uint256 _id) external {
        address borrower = msg.sender;
        require(!loans[_id].clamed, "Loan clamed");
        require(!loans[_id].finished, "Loan closed");
        require(loans[_id].borrower == borrower, "Not a borrower");

        uint256 loanFee = CalculateLoanFee(_id);
        loans[_id].clamed = true;
        tokenX.transferFrom(
            borrower,
            address(this),
            loans[_id].tokenX + loanFee
        );
        tokenA.transfer(borrower, loans[_id].tokenA);

        emit CollateralLoanReturned(
            borrower,
            loans[_id].tokenX,
            loanFee,
            loans[_id].tokenA,
            block.timestamp
        );
    }

    /**
     * @notice Calculate loan fee to the borrower. Based on retention period and loan fee rate.
     * @param _id lending-pool loan ID
     */
    function CalculateLoanFee(uint256 _id)
        public
        view
        returns (uint256 amount)
    {
        uint256 loanFeePerMonth = (loans[_id].tokenX * MONTH_PAYBACK_RATE) /
            100;
        uint256 monthsNum = (block.timestamp - loans[_id].loanUsed) / MONTH;
        for (uint256 i = 0; i <= monthsNum; i++) {
            amount += loanFeePerMonth;
        }
    }

    /**
     * @notice Returns loan structure
     * @param _id lending-pool loan ID
     */
    function getLoanById(uint256 _id) external view returns (Loan memory) {
        return loans[_id];
    }

    /**
     * @notice Safely cast an uint256 to an uint80
     * @param x convertible number
     */
    function u80(uint256 x) internal pure returns (uint80 y) {
        require(x <= type(uint80).max, "Cast overflow");
        y = uint80(x);
    }

    // BONUS: Can we add a check that allows the lender to take the collateral before the end of the lock period in case the previous situation applies?
    // ANSWER: Yes
    /**
     * @notice Determines if the loan fee exceeded the collateral
     * @param _id lending-pool loan ID
     */
    function CollateralLowerThanInterest(uint256 _id)
        public
        view
        returns (bool lower)
    {
        lower = CalculateLoanFee(_id) > loans[_id].tokenX;
    }

    // BONUS: Assuming that the exchange rate between token A and token X will be the same. What is the maximum period it is advised to issue a loan? I.E. Is there a moment where collateral will be lower than principal+interest?
    // ANSWER: With the condition that the interest is 10%, after 10 months the deposit will be less than collateral (10% * 10 = 100%)
}
