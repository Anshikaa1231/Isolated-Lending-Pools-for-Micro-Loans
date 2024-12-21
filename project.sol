// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MicroLoanLendingPools {
    struct Pool {
        address owner;
        uint256 interestRate; // Annual interest rate in basis points (1% = 100 bps)
        uint256 maxLoanAmount;
        uint256 totalLiquidity;
        uint256 totalBorrowed;
        mapping(address => uint256) balances;
    }

    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interest;
        uint256 dueDate;
        bool repaid;
    }

    Pool[] public pools;
    mapping(uint256 => Loan[]) public poolLoans;

    event PoolCreated(uint256 poolId, address owner, uint256 interestRate, uint256 maxLoanAmount);
    event LiquidityAdded(uint256 poolId, address provider, uint256 amount);
    event LoanTaken(uint256 poolId, address borrower, uint256 amount, uint256 dueDate);
    event LoanRepaid(uint256 poolId, address borrower, uint256 amount);

    function createPool(uint256 interestRate, uint256 maxLoanAmount) external returns (uint256) {
    Pool storage newPool = pools.push(); // Add a new pool to the array and get a reference to it
    newPool.owner = msg.sender;
    newPool.interestRate = interestRate;
    newPool.maxLoanAmount = maxLoanAmount;
    newPool.totalLiquidity = 0;
    newPool.totalBorrowed = 0;

    uint256 poolId = pools.length - 1;
    emit PoolCreated(poolId, msg.sender, interestRate, maxLoanAmount);
    return poolId;
}


    function addLiquidity(uint256 poolId) external payable {
        require(poolId < pools.length, "Invalid pool ID");
        Pool storage pool = pools[poolId];
        pool.balances[msg.sender] += msg.value;
        pool.totalLiquidity += msg.value;
        emit LiquidityAdded(poolId, msg.sender, msg.value);
    }

    function takeLoan(uint256 poolId, uint256 amount, uint256 duration) external {
        require(poolId < pools.length, "Invalid pool ID");
        Pool storage pool = pools[poolId];
        require(amount <= pool.maxLoanAmount, "Amount exceeds max loan amount");
        require(amount <= pool.totalLiquidity - pool.totalBorrowed, "Not enough liquidity");

        uint256 interest = (amount * pool.interestRate * duration) / (10000 * 365 days);
        uint256 dueDate = block.timestamp + duration;

        poolLoans[poolId].push(
            Loan({
                borrower: msg.sender,
                amount: amount,
                interest: interest,
                dueDate: dueDate,
                repaid: false
            })
        );

        pool.totalBorrowed += amount;
        payable(msg.sender).transfer(amount);

        emit LoanTaken(poolId, msg.sender, amount, dueDate);
    }

    function repayLoan(uint256 poolId, uint256 loanId) external payable {
        require(poolId < pools.length, "Invalid pool ID");
        require(loanId < poolLoans[poolId].length, "Invalid loan ID");

        Loan storage loan = poolLoans[poolId][loanId];
        require(msg.sender == loan.borrower, "Not the borrower");
        require(!loan.repaid, "Loan already repaid");
        require(msg.value >= loan.amount + loan.interest, "Insufficient repayment amount");

        Pool storage pool = pools[poolId];
        pool.totalBorrowed -= loan.amount;
        pool.balances[pool.owner] += loan.interest;

        loan.repaid = true;
        emit LoanRepaid(poolId, msg.sender, loan.amount);
    }

    function withdrawLiquidity(uint256 poolId, uint256 amount) external {
        require(poolId < pools.length, "Invalid pool ID");
        Pool storage pool = pools[poolId];
        require(pool.balances[msg.sender] >= amount, "Insufficient balance");
        require(pool.totalLiquidity - pool.totalBorrowed >= amount, "Insufficient available liquidity");

        pool.balances[msg.sender] -= amount;
        pool.totalLiquidity -= amount;
        payable(msg.sender).transfer(amount);
    }

    function getPoolDetails(uint256 poolId) external view returns (
        address owner,
        uint256 interestRate,
        uint256 maxLoanAmount,
        uint256 totalLiquidity,
        uint256 totalBorrowed
    ) {
        require(poolId < pools.length, "Invalid pool ID");
        Pool storage pool = pools[poolId];
        return (
            pool.owner,
            pool.interestRate,
            pool.maxLoanAmount,
            pool.totalLiquidity,
            pool.totalBorrowed
        );
    }

    function getLoanDetails(uint256 poolId, uint256 loanId) external view returns (
        address borrower,
        uint256 amount,
        uint256 interest,
        uint256 dueDate,
        bool repaid
    ) {
        require(poolId < pools.length, "Invalid pool ID");
        require(loanId < poolLoans[poolId].length, "Invalid loan ID");
        Loan storage loan = poolLoans[poolId][loanId];
        return (
            loan.borrower,
            loan.amount,
            loan.interest,
            loan.dueDate,
            loan.repaid
        );
    }
}
