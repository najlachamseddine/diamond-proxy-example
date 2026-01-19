// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LibAppStorage } from "../libraries/LibAppStorage.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";

/**
 * @title ERC20Facet
 * @dev ERC20 token implementation as a diamond facet
 * 
 * Demonstrates how a full token standard can be implemented
 * as a facet. All storage is in LibAppStorage.
 * 
 * Best Practices:
 * 1. Functions are stateless - all state in storage lib
 * 2. Can be upgraded without affecting token balances
 * 3. Shares storage with other facets safely
 */
contract ERC20Facet {
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);

    /**
     * @notice Initialize the ERC20 token (can only be called once)
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _decimals Token decimals
     */
    function initializeERC20(
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals
    ) external {
        LibDiamond.enforceIsContractOwner();
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(!s.initialized, "ERC20: already initialized");
        
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;
        s.initialized = true;
    }

    /**
     * @notice Returns the name of the token
     */
    function name() external view returns (string memory) {
        return LibAppStorage.appStorage().name;
    }

    /**
     * @notice Returns the symbol of the token
     */
    function symbol() external view returns (string memory) {
        return LibAppStorage.appStorage().symbol;
    }

    /**
     * @notice Returns the decimals of the token
     */
    function decimals() external view returns (uint8) {
        return LibAppStorage.appStorage().decimals;
    }

    /**
     * @notice Returns the total supply of the token
     */
    function totalSupply() external view returns (uint256) {
        return LibAppStorage.appStorage().totalSupply;
    }

    /**
     * @notice Returns the balance of an account
     */
    function balanceOf(address _account) external view returns (uint256) {
        return LibAppStorage.appStorage().balances[_account];
    }

    /**
     * @notice Transfer tokens to a recipient
     */
    function transfer(address _to, uint256 _value) external returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @notice Get the allowance of a spender for an owner
     */
    function allowance(address _owner, address _spender) external view returns (uint256) {
        return LibAppStorage.appStorage().allowances[_owner][_spender];
    }

    /**
     * @notice Approve a spender to spend tokens
     */
    function approve(address _spender, uint256 _value) external returns (bool) {
        _approve(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another
     */
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        uint256 currentAllowance = s.allowances[_from][msg.sender];
        
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < _value) {
                revert ERC20InsufficientAllowance(msg.sender, currentAllowance, _value);
            }
            unchecked {
                _approve(_from, msg.sender, currentAllowance - _value);
            }
        }
        
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * @notice Mint new tokens (only owner)
     */
    function mint(address _to, uint256 _amount) external {
        LibDiamond.enforceIsContractOwner();
        _mint(_to, _amount);
    }

    /**
     * @notice Burn tokens from an account
     */
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    // =============================================================
    //                     INTERNAL FUNCTIONS
    // =============================================================

    function _transfer(address _from, address _to, uint256 _value) internal {
        if (_from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        
        uint256 fromBalance = s.balances[_from];
        if (fromBalance < _value) {
            revert ERC20InsufficientBalance(_from, fromBalance, _value);
        }
        
        unchecked {
            s.balances[_from] = fromBalance - _value;
            s.balances[_to] += _value;
        }
        
        emit Transfer(_from, _to, _value);
    }

    function _mint(address _account, uint256 _value) internal {
        if (_account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.totalSupply += _value;
        
        unchecked {
            s.balances[_account] += _value;
        }
        
        emit Transfer(address(0), _account, _value);
    }

    function _burn(address _account, uint256 _value) internal {
        if (_account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        
        uint256 accountBalance = s.balances[_account];
        if (accountBalance < _value) {
            revert ERC20InsufficientBalance(_account, accountBalance, _value);
        }
        
        unchecked {
            s.balances[_account] = accountBalance - _value;
            s.totalSupply -= _value;
        }
        
        emit Transfer(_account, address(0), _value);
    }

    function _approve(address _owner, address _spender, uint256 _value) internal {
        if (_owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (_spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        
        LibAppStorage.appStorage().allowances[_owner][_spender] = _value;
        emit Approval(_owner, _spender, _value);
    }
}
