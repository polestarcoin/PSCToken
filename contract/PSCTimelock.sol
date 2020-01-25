pragma solidity ^0.5.0;

import "./PSC.sol";

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
	address public owner;

	event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

	/**
	 * @dev The Ownable constructor sets the original `owner` of the contract to the sender
	 * account.
	 */
	constructor () public {
		owner = msg.sender;
	}

	/**
	 * @dev Throws if called by any account other than the owner.
	 */
	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}

	/**
	 * @dev Allows the current owner to transfer control of the contract to a newOwner.
	 * @param newOwner The address to transfer ownership to.
	 */
	function transferOwnership(address newOwner) public onlyOwner {
		require(newOwner != address(0));
		emit OwnershipTransferred(owner, newOwner);
		owner = newOwner;
	}
	
}

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time.
 *
 * Useful for simple vesting schedules like "advisors get all of their tokens
 * after 1 year".
 *
 * For a more complete vesting schedule, see {TokenVesting}.
 */
contract PSCTokenTimelock is Ownable{
    // PSCToken contract being held
    PSCToken private _token;

    // beneficiary of tokens after they are released
    address private _beneficiary;

    // timestamp when token release is enabled
    uint256 private _releaseTime;
    
    // release monthly mapping
    mapping(uint256 => uint256) private _releaseMonths;//month timestamp->amount
    uint256[] private _monthTsArr;

    constructor (PSCToken token, address beneficiary, uint256 releaseTime) public {
        // solhint-disable-next-line not-rely-on-time
        require(releaseTime > block.timestamp, "PSCTokenTimelock: release time is before current time");
        _token = token;
        _beneficiary = beneficiary;
        _releaseTime = releaseTime;
    }

    /**
     * @return the token being held.
     */
    function token() public view returns (PSCToken) {
        return _token;
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @return the time when the tokens are released.
     */
    function releaseTime() public view returns (uint256) {
        return _releaseTime;
    }
    
    function addMonthRelease(uint256 monthTs, uint256 amount) public onlyOwner {
        require(monthTs <= _releaseTime, "PSCTokenTimelock: monthTs should be less than or equal to _releaseTime");
        _releaseMonths[monthTs] = amount;
        _monthTsArr.push(monthTs);
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public onlyOwner {
        // solhint-disable-next-line not-rely-on-time
        uint256 amount = _token.balanceOf(address(this));
        require(amount > 0, "PSCTokenTimelock: no tokens to release");
        
        uint lenM = _monthTsArr.length;
        if (lenM > 0) {
            if (block.timestamp < _releaseTime) {
                uint monTsT = _monthTsArr[0];  
                for (uint i = 0; i < lenM; i++) {
                    monTsT = _monthTsArr[i];
                    if (block.timestamp >= monTsT) {
                        _token.transfer(_beneficiary, _releaseMonths[monTsT]);
                    }
                }
            } else {
                _token.transfer(_beneficiary, amount);
            }
        }else {
            require(block.timestamp >= _releaseTime, "PSCTokenTimelock: current time is before release time");
            _token.transfer(_beneficiary, amount);
        }
    }
}
