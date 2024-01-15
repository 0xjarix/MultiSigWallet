// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MultiSigWallet {
    // errors
    error MultiSigWallet__TransactionNotApproved();
    error MultiSigWallet__TransactionAlreadyExecuted();
    error MultiSigWallet__TransactionDoesNotExist();
    error MultiSigWallet__OnlyOwnersCanCancelTransactions();
    error MultiSigWallet__OnlyOwnersCanSubmitTransactions();
    error MultiSigWallet__OnlyOwnersCanApproveTransactions();
    error MultiSigWallet__TransactionAlreadyApproved();
    error MultiSigWallet__WalletCannotHaveZeroOwner();
    error MultiSigWallet__ThresholdCannotBeZero();
    error MultiSigWallet__ThresholdCannotBeGreaterThanOwners();
    error MultiSigWallet__InvalidOwnerAddress();

    // state variables
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        address[] approvers;
    }

    Transaction[] public transactions;

    // events
    event Deposit(address indexed sender, uint256 value);
    event TransactionSubmitted(
        address indexed sender,
        address indexed to,
        uint256 value,
        uint256 indexed transactionId
    );
    event Approval(address indexed sender, uint256 indexed transactionId);
    event Execution(address indexed sender, uint256 indexed transactionId);
    event TransactionCancelled(address indexed sender, uint256 indexed transactionId);

    constructor(address[] memory _owners, uint256 _threshold) {
        if (_owners.length == 0)
            revert MultiSigWallet__WalletCannotHaveZeroOwner();
        if (_threshold == 0)
            revert MultiSigWallet__ThresholdCannotBeZero();
        if (_threshold > _owners.length)
            revert MultiSigWallet__ThresholdCannotBeGreaterThanOwners();

        for (uint256 i = 0; i < _owners.length; ) {
            address owner = _owners[i];
            if (owner == address(0))
                revert MultiSigWallet__InvalidOwnerAddress();
            if (isOwner[owner])
                revert MultiSigWallet__InvalidOwnerAddress();
            isOwner[owner] = true;
            owners.push(owner);
            unchecked{
                i++;
            }
        }

        threshold = _threshold;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) external {
        if (!isOwner[msg.sender])
            revert MultiSigWallet__OnlyOwnersCanSubmitTransactions();
        uint256 transactionId = transactions.length;
        transactions.push(Transaction(_to, _value, _data, false, new address[](0)));

        emit TransactionSubmitted(msg.sender, _to, _value, transactionId);
    }

    function approveTransaction(uint256 _transactionId)
        external
    {
        if (!isOwner[msg.sender])
            revert MultiSigWallet__OnlyOwnersCanApproveTransactions();
        if (_transactionId > transactions.length - 1)
            revert MultiSigWallet__TransactionDoesNotExist();
        if (transactions[_transactionId].executed)
            revert MultiSigWallet__TransactionAlreadyExecuted();
        if (isApprover(_transactionId, msg.sender))
            revert MultiSigWallet__TransactionAlreadyApproved();
        transactions[_transactionId].approvers.push(msg.sender);

        emit Approval(msg.sender, _transactionId);

        if (isTransactionApproved(_transactionId)) {
            executeTransaction(_transactionId);
        }
    }

    function cancelTransaction(uint256 _transactionId)
        external
    {
        if (!isOwner[msg.sender])
            revert MultiSigWallet__OnlyOwnersCanCancelTransactions();
        if (_transactionId > transactions.length - 1)
            revert MultiSigWallet__TransactionDoesNotExist();
        if (transactions[_transactionId].executed)
            revert MultiSigWallet__TransactionAlreadyExecuted();
        transactions[_transactionId].executed = true;

        emit TransactionCancelled(msg.sender, _transactionId);
    }

    function isTransactionApproved(uint256 _transactionId) public view returns (bool) {
        return transactions[_transactionId].approvers.length >= threshold;
    }

    function isApprover(uint256 _transactionId, address _approver) internal view returns (bool) {
        address[] memory approvers = transactions[_transactionId].approvers;
        for (uint256 i = 0; i < approvers.length;) {
            if (approvers[i] == _approver) {
                return true;
            }
            unchecked{
                i++;
            }
        }
        return false;
    }

    function executeTransaction(uint256 _transactionId)
        internal
    {
        if (_transactionId > transactions.length - 1)
            revert MultiSigWallet__TransactionDoesNotExist();
        if (transactions[_transactionId].executed)
            revert MultiSigWallet__TransactionAlreadyExecuted();
        if (!isTransactionApproved(_transactionId))
            revert MultiSigWallet__TransactionNotApproved();

        transactions[_transactionId].executed = true;
/*
        (bool success, ) = transactions[_transactionId].to.call{value: transactions[_transactionId].value}(
            transactions[_transactionId].data
        );
        require(success, "Transaction execution failed");*/
        Address.sendValue(payable(transactions[_transactionId].to), transactions[_transactionId].value);
        emit Execution(msg.sender, _transactionId);
    }

    // getters
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTransactionTo(uint256 _transactionId)
        external
        view
        returns (
            address to
        )
    {
        if (_transactionId > transactions.length - 1)
            revert MultiSigWallet__TransactionDoesNotExist();
        Transaction storage transaction = transactions[_transactionId];
        return transaction.to;
    }

    function getTransactionValue(uint256 _transactionId)
        external
        view
        returns (
            uint256 value
        )
    {
        if (_transactionId > transactions.length - 1)
            revert MultiSigWallet__TransactionDoesNotExist();
        Transaction storage transaction = transactions[_transactionId];
        return transaction.value;
    }

    function getTransactionData(uint256 _transactionId)
        external
        view
        returns (
            bytes memory data
        )
    {
        if (_transactionId > transactions.length - 1)
            revert MultiSigWallet__TransactionDoesNotExist();
        Transaction storage transaction = transactions[_transactionId];
        return transaction.data;
    }

    function getTransactionExecuted(uint256 _transactionId)
        external
        view
        returns (
            bool executed
        )
    {
        if (_transactionId > transactions.length - 1)
            revert MultiSigWallet__TransactionDoesNotExist();
        Transaction storage transaction = transactions[_transactionId];
        return transaction.executed;
    }

    function getTransactionApprovers(uint256 _transactionId)
        external
        view
        returns (
            address[] memory approvers
        )
    {
        if (_transactionId > transactions.length - 1)
            revert MultiSigWallet__TransactionDoesNotExist();
        Transaction storage transaction = transactions[_transactionId];
        return transaction.approvers;
    }
}