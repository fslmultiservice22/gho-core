// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoToken is TestGhoBase {
  function testConstructor() public {
    GhoToken ghoToken = new GhoToken();
    assertEq(ghoToken.name(), 'Gho Token', 'Wrong default ERC20 name');
    assertEq(ghoToken.symbol(), 'GHO', 'Wrong default ERC20 symbol');
    assertEq(ghoToken.decimals(), 18, 'Wrong default ERC20 decimals');
    assertEq(ghoToken.getFacilitatorsList().length, 0, 'Facilitator list not empty');
  }

  function testSetAndGetBucketManager() public {
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit BucketManagerTransferred(address(0), ALICE);
    GHO_TOKEN.setBucketManager(ALICE);
    assertEq(GHO_TOKEN.getBucketManager(), ALICE, 'Unexpected bucket manager');
  }

  function testGetFacilitatorData() public {
    IGhoToken.Facilitator memory data = GHO_TOKEN.getFacilitator(address(GHO_ATOKEN));
    assertEq(data.label, 'Aave V3 Pool', 'Unexpected facilitator label');
    assertEq(data.bucketCapacity, DEFAULT_CAPACITY, 'Unexpected bucket capacity');
    assertEq(data.bucketLevel, 0, 'Unexpected bucket level');
  }

  function testGetNonFacilitatorData() public {
    IGhoToken.Facilitator memory data = GHO_TOKEN.getFacilitator(ALICE);
    assertEq(data.label, '', 'Unexpected facilitator label');
    assertEq(data.bucketCapacity, 0, 'Unexpected bucket capacity');
    assertEq(data.bucketLevel, 0, 'Unexpected bucket level');
  }

  function testGetFacilitatorBucket() public {
    (uint256 capacity, uint256 level) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, DEFAULT_CAPACITY, 'Unexpected bucket capacity');
    assertEq(level, 0, 'Unexpected bucket level');
  }

  function testGetNonFacilitatorBucket() public {
    (uint256 capacity, uint256 level) = GHO_TOKEN.getFacilitatorBucket(ALICE);
    assertEq(capacity, 0, 'Unexpected bucket capacity');
    assertEq(level, 0, 'Unexpected bucket level');
  }

  function testGetPopulatedFacilitatorsList() public {
    address[] memory facilitatorList = GHO_TOKEN.getFacilitatorsList();
    assertEq(facilitatorList.length, 4, 'Unexpected number of facilitators');
    assertEq(facilitatorList[0], address(GHO_ATOKEN), 'Unexpected address for mock facilitator 1');
    assertEq(
      facilitatorList[1],
      address(GHO_FLASH_MINTER),
      'Unexpected address for mock facilitator 2'
    );
    assertEq(
      facilitatorList[2],
      address(FLASH_BORROWER),
      'Unexpected address for mock facilitator 3'
    );
    assertEq(facilitatorList[3], FAUCET, 'Unexpected address for mock facilitator 4');
  }

  function testAddFacilitator() public {
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit FacilitatorAdded(ALICE, keccak256(abi.encodePacked('Alice')), DEFAULT_CAPACITY);
    GHO_TOKEN.addFacilitator(ALICE, 'Alice', DEFAULT_CAPACITY);
  }

  function testRevertAddExistingFacilitator() public {
    vm.expectRevert('FACILITATOR_ALREADY_EXISTS');
    GHO_TOKEN.addFacilitator(address(GHO_ATOKEN), 'Aave V3 Pool', DEFAULT_CAPACITY);
  }

  function testRevertAddFacilitatorNoLabel() public {
    vm.expectRevert('INVALID_LABEL');
    GHO_TOKEN.addFacilitator(ALICE, '', DEFAULT_CAPACITY);
  }

  function testRevertSetBucketCapacityNonFacilitator() public {
    vm.expectRevert('FACILITATOR_DOES_NOT_EXIST');
    GHO_TOKEN.setFacilitatorBucketCapacity(ALICE, DEFAULT_CAPACITY);
  }

  function testSetNewBucketCapacity() public {
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketCapacityUpdated(address(GHO_ATOKEN), DEFAULT_CAPACITY, 0);
    GHO_TOKEN.setFacilitatorBucketCapacity(address(GHO_ATOKEN), 0);
  }

  function testRevertSetNewBucketCapacityNonOwner() public {
    vm.prank(ALICE);
    vm.expectRevert(bytes('CALLER_NOT_BUCKET_MANAGER_OR_OWNER'));
    GHO_TOKEN.setFacilitatorBucketCapacity(address(GHO_ATOKEN), 0);
  }

  function testSetNewBucketCapacityViaManager() public {
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit BucketManagerTransferred(address(0), ALICE);
    GHO_TOKEN.setBucketManager(ALICE);
    assertTrue(
      GHO_TOKEN.owner() != GHO_TOKEN.getBucketManager(),
      'Bucket manager should not equal owner'
    );
    vm.prank(ALICE);
    emit FacilitatorBucketCapacityUpdated(address(GHO_ATOKEN), DEFAULT_CAPACITY, 0);
    GHO_TOKEN.setFacilitatorBucketCapacity(address(GHO_ATOKEN), 0);
  }

  function testRevertSetNewBucketCapacityViaManagerNonZeroCap() public {
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit BucketManagerTransferred(address(0), ALICE);
    GHO_TOKEN.setBucketManager(ALICE);
    assertTrue(
      GHO_TOKEN.owner() != GHO_TOKEN.getBucketManager(),
      'Bucket manager should not equal owner'
    );
    vm.prank(ALICE);
    vm.expectRevert('BUCKET_MANAGER_MUST_SET_ZERO_CAPACITY');
    GHO_TOKEN.setFacilitatorBucketCapacity(address(GHO_ATOKEN), 1);
  }

  function testRevertRemoveNonFacilitator() public {
    vm.expectRevert('FACILITATOR_DOES_NOT_EXIST');
    GHO_TOKEN.removeFacilitator(ALICE);
  }

  function testRevertRemoveFacilitatorNonZeroBucket() public {
    ghoFaucet(ALICE, 1);
    vm.expectRevert('FACILITATOR_BUCKET_LEVEL_NOT_ZERO');
    GHO_TOKEN.removeFacilitator(FAUCET);
  }

  function testRemoveFacilitator() public {
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorRemoved(address(GHO_ATOKEN));
    GHO_TOKEN.removeFacilitator(address(GHO_ATOKEN));
  }

  function testRevertMintBadFacilitator() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_FACILITATOR');
    GHO_TOKEN.mint(ALICE, DEFAULT_BORROW_AMOUNT);
  }

  function testRevertMintExceedCapacity() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectRevert('FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
    GHO_TOKEN.mint(ALICE, DEFAULT_CAPACITY + 1);
  }

  function testMint() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit Transfer(address(0), ALICE, DEFAULT_CAPACITY);
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketLevelUpdated(address(GHO_ATOKEN), 0, DEFAULT_CAPACITY);
    GHO_TOKEN.mint(ALICE, DEFAULT_CAPACITY);
  }

  function testRevertZeroBurn() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectRevert('INVALID_BURN_AMOUNT');
    GHO_TOKEN.burn(0);
  }

  function testRevertBurnMoreThanMinted() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketLevelUpdated(address(GHO_ATOKEN), 0, DEFAULT_CAPACITY);
    GHO_TOKEN.mint(address(GHO_ATOKEN), DEFAULT_CAPACITY);

    vm.prank(address(GHO_ATOKEN));
    vm.expectRevert(stdError.arithmeticError);
    GHO_TOKEN.burn(DEFAULT_CAPACITY + 1);
  }

  function testRevertBurnOthersTokens() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit Transfer(address(0), ALICE, DEFAULT_CAPACITY);
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketLevelUpdated(address(GHO_ATOKEN), 0, DEFAULT_CAPACITY);
    GHO_TOKEN.mint(ALICE, DEFAULT_CAPACITY);

    vm.prank(address(GHO_ATOKEN));
    vm.expectRevert(stdError.arithmeticError);
    GHO_TOKEN.burn(DEFAULT_CAPACITY);
  }

  function testBurn() public {
    vm.prank(address(GHO_ATOKEN));
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit Transfer(address(0), address(GHO_ATOKEN), DEFAULT_CAPACITY);
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketLevelUpdated(address(GHO_ATOKEN), 0, DEFAULT_CAPACITY);
    GHO_TOKEN.mint(address(GHO_ATOKEN), DEFAULT_CAPACITY);

    vm.prank(address(GHO_ATOKEN));
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorBucketLevelUpdated(
      address(GHO_ATOKEN),
      DEFAULT_CAPACITY,
      DEFAULT_CAPACITY - DEFAULT_BORROW_AMOUNT
    );
    GHO_TOKEN.burn(DEFAULT_BORROW_AMOUNT);
  }

  function testOffboardFacilitator() public {
    // Onboard facilitator
    vm.expectEmit(true, true, false, true, address(GHO_TOKEN));
    emit FacilitatorAdded(ALICE, keccak256(abi.encodePacked('Alice')), DEFAULT_CAPACITY);
    GHO_TOKEN.addFacilitator(ALICE, 'Alice', DEFAULT_CAPACITY);

    // Facilitator mints half of its capacity
    vm.prank(ALICE);
    GHO_TOKEN.mint(ALICE, DEFAULT_CAPACITY / 2);
    (uint256 bucketCapacity, uint256 bucketLevel) = GHO_TOKEN.getFacilitatorBucket(ALICE);
    assertEq(bucketCapacity, DEFAULT_CAPACITY, 'Unexpected bucket capacity of facilitator');
    assertEq(bucketLevel, DEFAULT_CAPACITY / 2, 'Unexpected bucket level of facilitator');

    // Facilitator cannot be removed
    vm.expectRevert('FACILITATOR_BUCKET_LEVEL_NOT_ZERO');
    GHO_TOKEN.removeFacilitator(ALICE);

    // Facilitator Bucket Capacity set to 0
    GHO_TOKEN.setFacilitatorBucketCapacity(ALICE, 0);

    // Facilitator cannot mint more and is expected to burn remaining level
    vm.prank(ALICE);
    vm.expectRevert('INVALID_FACILITATOR');
    GHO_TOKEN.mint(ALICE, 1);

    vm.prank(ALICE);
    GHO_TOKEN.burn(bucketLevel);

    // Facilitator can be removed with 0 bucket level
    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorRemoved(address(ALICE));
    GHO_TOKEN.removeFacilitator(address(ALICE));
  }

  function testDomainSeparator() public {
    bytes32 EIP712_DOMAIN = keccak256(
      'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
    );
    bytes memory EIP712_REVISION = bytes('1');
    bytes32 expected = keccak256(
      abi.encode(
        EIP712_DOMAIN,
        keccak256(bytes(GHO_TOKEN.name())),
        keccak256(EIP712_REVISION),
        block.chainid,
        address(GHO_TOKEN)
      )
    );
    bytes32 result = GHO_TOKEN.DOMAIN_SEPARATOR();
    assertEq(result, expected, 'Unexpected domain separator');
  }

  function testDomainSeparatorNewChain() public {
    vm.chainId(31338);
    bytes32 EIP712_DOMAIN = keccak256(
      'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
    );
    bytes memory EIP712_REVISION = bytes('1');
    bytes32 expected = keccak256(
      abi.encode(
        EIP712_DOMAIN,
        keccak256(bytes(GHO_TOKEN.name())),
        keccak256(EIP712_REVISION),
        block.chainid,
        address(GHO_TOKEN)
      )
    );
    bytes32 result = GHO_TOKEN.DOMAIN_SEPARATOR();
    assertEq(result, expected, 'Unexpected domain separator');
  }

  function testPermitAndVerifyNonce() public {
    address david = vm.addr(31338);
    ghoFaucet(david, 1e18);
    bytes32 PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    bytes32 innerHash = keccak256(abi.encode(PERMIT_TYPEHASH, david, BOB, 1e18, 0, 1 hours));
    bytes32 outerHash = keccak256(
      abi.encodePacked('\x19\x01', GHO_TOKEN.DOMAIN_SEPARATOR(), innerHash)
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(31338, outerHash);
    GHO_TOKEN.permit(david, BOB, 1e18, 1 hours, v, r, s);

    assertEq(GHO_TOKEN.allowance(david, BOB), 1e18, 'Unexpected allowance');
    assertEq(GHO_TOKEN.nonces(david), 1, 'Unexpected nonce');
  }

  function testRevertPermitInvalidSignature() public {
    bytes32 PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    bytes32 innerHash = keccak256(abi.encode(PERMIT_TYPEHASH, ALICE, BOB, 1e18, 0, 1 hours));
    bytes32 outerHash = keccak256(
      abi.encodePacked('\x19\x01', GHO_TOKEN.DOMAIN_SEPARATOR(), innerHash)
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(31338, outerHash);
    vm.expectRevert(bytes('INVALID_SIGNER'));
    GHO_TOKEN.permit(ALICE, BOB, 1e18, 1 hours, v, r, s);
  }

  function testRevertPermitInvalidDeadline() public {
    vm.expectRevert(bytes('PERMIT_DEADLINE_EXPIRED'));
    GHO_TOKEN.permit(ALICE, BOB, 1e18, block.timestamp - 1, 0, 0, 0);
  }
}
